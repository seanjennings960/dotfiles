import unittest
from unittest.mock import patch

from click.testing import CliRunner

from dotfiles_dev.cli import cli


class LocalContextTests(unittest.TestCase):
    def test_inspection_reports_invoking_environment(self):
        for environment in ("host", "container"):
            with self.subTest(environment=environment):
                result = CliRunner().invoke(cli, ["env"], env={"DEV_ENVIRONMENT": environment})
                self.assertEqual(result.exit_code, 0, result.output)
                self.assertIn(f"Environment: {environment}", result.output)

    def test_cross_environment_entry_never_launches(self):
        for current, target in (("host", "container"), ("container", "host")):
            with self.subTest(current=current), patch("dotfiles_dev.cli.Local") as local:
                result = CliRunner().invoke(cli, ["env", "enter", target],
                                            env={"DEV_ENVIRONMENT": current})
                self.assertNotEqual(result.exit_code, 0)
                self.assertIn("No command was run", result.output)
                local.assert_not_called()

    def test_unknown_environment_rejects_execution(self):
        with patch("dotfiles_dev.cli.replace") as execute:
            result = CliRunner().invoke(cli, ["exec", "true"],
                                        env={"DEV_ENVIRONMENT": "unknown"})
            self.assertNotEqual(result.exit_code, 0)
            execute.assert_not_called()

    def test_entry_uses_local_container_session(self):
        with patch("dotfiles_dev.cli.Local") as local:
            result = CliRunner().invoke(cli, [], env={"DEV_ENVIRONMENT": "container"})
            self.assertEqual(result.exit_code, 0, result.output)
            local.assert_called_once_with("container")
            local.return_value.enter.assert_called_once()
