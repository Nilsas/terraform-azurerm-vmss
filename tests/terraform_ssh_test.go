package test

import (
	"fmt"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

func TestTerraformSshExample(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "./fixture_lin",

		Vars: map[string]interface{}{},
	}

	terraform.InitAndApply(t, terraformOptions)
	defer terraform.Destroy(t, terraformOptions)

	testSSHToPublicHost(t, terraformOptions, "ssh_conn_info", "ssh_priv_key")
}

func testSSHToPublicHost(t *testing.T, terraformOptions *terraform.Options, sshInfo string, privKey string) {
	// It can take a minute or so for the virtual machine to boot up, so retry a few times
	maxRetries := 15
	timeBetweenRetries := 5 * time.Second

	// Read private key from terraform output
	buffer := terraform.Output(t, terraformOptions, privKey)

	keyPair := ssh.KeyPair{PrivateKey: string(buffer)}

	sshHosts := getInstanceConnectionInfo(t, terraformOptions, sshInfo)

	wg := &sync.WaitGroup{}
	for _, instance := range sshHosts {
		wg.Add(1)
		go func(instance string) {
			defer wg.Done()
			instanceParts := strings.Split(instance, "=")
			address := strings.Split(instanceParts[1], ":")
			port, _ := strconv.Atoi(address[1])

			publicHost := ssh.Host{
				Hostname:    address[0],
				SshKeyPair:  &keyPair,
				SshUserName: "batman",
				CustomPort:  port,
			}

			// Print where are we connecting
			description := fmt.Sprintf("SSH to public host %s on port %d", publicHost.Hostname, publicHost.CustomPort)

			// Run a simple echo command on the server
			expectedText := "Hello, World"
			command := fmt.Sprintf("echo -n '%s'", expectedText)

			// Verify that we can SSH to the virtual machine and run commands
			retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
				// Run the command and get the output
				actualText, err := ssh.CheckSshCommandE(t, publicHost, command)
				if err != nil {
					return "", err
				}

				// Check whether the output is correct
				if strings.TrimSpace(actualText) != expectedText {
					return "", fmt.Errorf("Expected SSH command to return '%s' but got '%s'", expectedText, actualText)
				}
				fmt.Println(actualText)

				return "", nil
			})
		}(instance)
	}
	wg.Wait()
}

func getInstanceConnectionInfo(t *testing.T, terraformOptions *terraform.Options, outputName string) []string {
	// Test case is carried with 2 instances
	// If there are more than 2 instance in the list, wait
	// Azure over-provisions Instances to maximize success rate
	// retry for 5 minutes
	var sshHosts []string
	for i := 0; i < 30 ; i++ {
		// Read public IP address and port from terraform output
		hostsResult := terraform.Output(t, terraformOptions, outputName)

		// Clean up hosts result
		hostsResult = strings.ReplaceAll(hostsResult, "\n", "")
		hostsResult = strings.ReplaceAll(hostsResult, " ", "")
		hostsResult = strings.ReplaceAll(hostsResult, `""`, `","`)
		hostsResult = strings.ReplaceAll(hostsResult, "{", "")
		hostsResult = strings.ReplaceAll(hostsResult, "}", "")
		hostsResult = strings.ReplaceAll(hostsResult, `"`, "")

		// Split up cleaned result
		sshHosts := strings.Split(hostsResult, ",")
		fmt.Println("Current ssh hosts:")
		fmt.Println(sshHosts)

		if len(sshHosts) > 2 {
			time.Sleep(10 * time.Second)
			fmt.Println("Sleeping for 10 seconds")
		} else if len(sshHosts) == 2 {
			break
		} else {
			fmt.Println("SSH Hosts count did not match expectations")
		}
	}

	return sshHosts
}