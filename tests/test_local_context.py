from unittest.mock import patch

import pytest
from click.testing import CliRunner

from dotfiles_dev.cli import cli


@pytest.fixture
def runner():
    return CliRunner()


@pytest.mark.parametrize("environment", ["host", "container"])
def test_inspection_reports_invoking_environment(runner, environment):
    result = runner.invoke(cli, ["env"], env={"DEV_ENVIRONMENT": environment})
    assert result.exit_code == 0, result.output
    assert f"Environment: {environment}" in result.output


@pytest.mark.parametrize("current, target", [("host", "container"), ("container", "host")])
def test_cross_environment_entry_never_launches(runner, current, target):
    with patch("dotfiles_dev.cli.Local") as local:
        result = runner.invoke(cli, ["env", "enter", target],
                               env={"DEV_ENVIRONMENT": current})
        assert result.exit_code != 0
        assert "No command was run" in result.output
        local.assert_not_called()


def test_unknown_environment_rejects_execution(runner):
    with patch("dotfiles_dev.cli.replace") as execute:
        result = runner.invoke(cli, ["exec", "true"],
                               env={"DEV_ENVIRONMENT": "unknown"})
        assert result.exit_code != 0
        execute.assert_not_called()


def test_entry_uses_local_container_session(runner):
    with patch("dotfiles_dev.cli.Local") as local:
        result = runner.invoke(cli, [], env={"DEV_ENVIRONMENT": "container"})
        assert result.exit_code == 0, result.output
        local.assert_called_once_with("container")
        local.return_value.enter.assert_called_once()
