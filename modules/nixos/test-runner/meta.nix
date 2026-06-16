{
  name = "test-runner";
  description = "Centralized test runner that discovers and executes module-level smoke tests and health checks at runtime via a oneshot systemd service, with a buildable script for CI/CD use";
  category = "testing";
  tags = [ "testing" "test-runner" "smoke-tests" "health-checks" "ci" "oneshot" ];
  provides = [ "my.testing" ];
  complexity = "simple";
  tested = true;
}
