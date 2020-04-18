package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
)


func TestTerraformWinRM(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "./fixture_win",

		Vars: map[string]interface{}{},
	}

	terraform.InitAndApply(t, terraformOptions)
	defer terraform.Destroy(t, terraformOptions)
	hosts := getInstanceConnInfo(t, terraformOptions)
	fmt.Println(hosts)
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