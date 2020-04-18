package test

import (
	"testing"

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

}
