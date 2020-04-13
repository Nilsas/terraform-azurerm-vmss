package test

import (
	"fmt"
	"strings"
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

func configureTerraformOptions(t *testing.T, exampleFolder string) *terraform.Options {

	terraformOptions := &terraform.Options{
		// The path to where our Terraform code is located
		TerraformDir: exampleFolder,

		// Variables to pass to our Terraform code using -var options
		Vars: map[string]interface{}{},
	}

	return terraformOptions
}

func testSSHToPublicHost(t *testing.T, terraformOptions *terraform.Options, sshInfo string, privKey string) {
	// It can take a minute or so for the virtual machine to boot up, so retry a few times
	maxRetries := 15
	timeBetweenRetries := 5 * time.Second

	// Read private key from terraform output
	buffer := terraform.Output(t, terraformOptions, privKey)

	keyPair := ssh.KeyPair{PrivateKey: string(buffer)}

	// Read public IP address and port from terarform output
	sshHosts := terraform.Output(t, terraformOptions, sshInfo)

	for _, value := range sshHosts {
		// Split Host IP and Port to give us a list
		host := strings.Split(value, ":")

		// Agreggate SSH information to pass into execution
		publicHost := ssh.Host{
			Hostname:    host[0],
			SshKeyPair:  &keyPair,
			SshUserName: "batman",
			CustomPort:  host[1],
		}

		// Print where are we connecting
		description := fmt.Sprintf("SSH to public host %s on port %d", host[0], host[1])

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
	}
}
