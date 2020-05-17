package test

import (
	"fmt"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/masterzen/winrm"
)


func TestTerraformWinRM(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "./fixture_win",

		Vars: map[string]interface{}{},
	}

	terraform.InitAndApply(t, terraformOptions)
	defer terraform.Destroy(t, terraformOptions)

	testWinRMToPublicHost(t, terraformOptions)
}

func testWinRMToPublicHost(t *testing.T, terraformOptions *terraform.Options)  {
	// It can take a minute or so for the virtual machine to boot up, so retry a few times
	maxRetries := 15
	timeBetweenRetries := 5 * time.Second

	// Read user, password from terraform output
	user := terraform.Output(t, terraformOptions, "winrm_user")
	pass := terraform.Output(t, terraformOptions, "winrm_pass")

	hosts := getInstanceConnInfo(t, terraformOptions)

	wg := &sync.WaitGroup{}
	for _, instance := range hosts {
		wg.Add(1)
		go func(instance string) {
			instanceParts := strings.Split(instance, "=")
			address := strings.Split(instanceParts[1], ":")
			port, _ := strconv.Atoi(address[1])

			endpoint := winrm.NewEndpoint(address[0], port, false, false, nil, nil, nil, 0)
			client, err := winrm.NewClient(endpoint, user, pass)
			if err != nil {
				panic(err)
			}

			// Print where are we connecting
			description := fmt.Sprintf("WinRM to public host %s on port %d", address[0], port)
			expectedText := "Hello, World"
			command := fmt.Sprintf("echo '%s'", expectedText)

			// Verify that we can WinRM to the Virtual Machine and run commands
			retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
				// Run the command and get the output
				actualText, _, _ ,err := client.RunWithString(command, "")
				if err != nil {
					return "", err
				}

				// Check whether the output is correct
				if strings.TrimSpace(actualText) != expectedText {
					return "", fmt.Errorf("Expected WinRM command to return '%s' but got '%s'", expectedText, actualText)
				}
				fmt.Println(actualText)

				return "", nil
			})

		}(instance)
	}
	wg.Wait()
}

func getInstanceConnInfo(t *testing.T, terraformOptions *terraform.Options) []string  {
	var winrmHosts []string
	connInfo := "winrm_conn_info"
	for i := 0; i < 5 ; i++ {
		// set terraform options to target just the resource I need

		hostsResult := terraform.Output(t, terraformOptions, connInfo)

		// Clean up hosts result
		hostsResult = strings.ReplaceAll(hostsResult, "\n", "")
		hostsResult = strings.ReplaceAll(hostsResult, " ", "")
		hostsResult = strings.ReplaceAll(hostsResult, `""`, `","`)
		hostsResult = strings.ReplaceAll(hostsResult, "{", "")
		hostsResult = strings.ReplaceAll(hostsResult, "}", "")
		hostsResult = strings.ReplaceAll(hostsResult, `"`, "")

		// Split up cleaned result
		winrmHosts := strings.Split(hostsResult, ",")
		fmt.Println("Current winrm hosts:")
		fmt.Println(winrmHosts)

		if len(winrmHosts) > 2 {
			fmt.Println("Sleeping for 30 seconds")
			time.Sleep(30 * time.Second)

		} else if len(winrmHosts) == 2 {
			break
		} else {
			fmt.Println("WinRM Hosts count did not match expectations")
		}
	}

	return winrmHosts
}