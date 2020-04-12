package test

import (
	"fmt"
	"os"
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

	testSSHToPublicHost(t, terraformOptions, "public_ip_address", "ssh_priv_key")
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

func testSSHToPublicHost(t *testing.T, terraformOptions *terraform.Options, address string, priv_key string) {
	// Run `terraform output` to get the value of an output variable
	publicIP := terraform.Output(t, terraformOptions, address)

	// Read private key from given file
	buffer := terraform.Output(t, terraformOptions, priv_key)

	keyPair := ssh.KeyPair{PrivateKey: string(buffer)}

	// We're going to try to SSH to the virtual machine, using our local key pair and specific username
	publicHost := ssh.Host{
		Hostname:    publicIP,
		SshKeyPair:  &keyPair,
		SshUserName: os.Args[len(os.Args)-2],
	}

	// It can take a minute or so for the virtual machine to boot up, so retry a few times
	maxRetries := 15
	timeBetweenRetries := 5 * time.Second
	description := fmt.Sprintf("SSH to public host %s", publicIP)

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
