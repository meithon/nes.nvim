#!/usr/bin/env python
import json
import os
import sys
from abc import ABC, abstractmethod

import requests


class Adapter(ABC):
    @property
    @abstractmethod
    def token(self) -> str:
        pass

    @property
    @abstractmethod
    def base_url(self) -> str:
        pass

    @property
    @abstractmethod
    def model(self) -> str:
        pass

    @property
    def headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
        }

    def ask(self, payload):
        rsp = requests.post(
            f"{self.base_url}/chat/completions",
            json=payload,
            headers=self.headers,
            stream=True,
        )
        rsp.raise_for_status()
        output = ""
        for line in rsp.iter_lines(decode_unicode=True):
            if not line:
                continue
            if line.startswith("data:"):
                line = line[5:].strip()
            if line == "[DONE]":
                break
            data = json.loads(line)
            if "choices" in data and len(data["choices"]) > 0:
                output += data["choices"][0]["delta"].get("content", "")
        print(output)


class Copilot(Adapter):
    _USER_AGENT = "vscode-chat/dev"
    _OAUTH_TOKEN_URL = "https://api.github.com/copilot_internal/v2/token"

    @property
    def _oauth_token(self) -> str:
        config_dir = os.environ.get(
            "XDG_CONFIG_HOME", os.path.join(os.environ["HOME"], ".config")
        )

        with open(os.path.join(config_dir, "github-copilot/apps.json")) as f:
            obj = json.load(f)
            for key, value in obj.items():
                if key.startswith("github.com:"):
                    return value["oauth_token"]
            raise RuntimeError("Could not find token")

    @property
    def token(self) -> str:
        rsp = requests.get(
            self._OAUTH_TOKEN_URL,
            headers={
                "Authorization": f"Bearer {self._oauth_token}",
                "Accept": "application/json",
                "User-Agent": self._USER_AGENT,
            },
        )
        rsp.raise_for_status()
        token = rsp.json()["token"]
        return token

    @property
    def base_url(self) -> str:
        # return "https://api.githubcopilot.com"
        return "https://proxy.business.githubcopilot.com"

    @property
    def model(self) -> str:
        return os.environ.get("COPILOT_MODEL", "gpt-4o")

    @property
    def headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.token}",
            "Content-Type": "application/json",
            "Copilot-Integration-Id": "vscode-chat",
            "editor-version": "Neovim/0.11.0",
            "editor-plugin-version": "nes/0.1.0",
            "User-Agent": self._USER_AGENT,
        }


def main():
    payload = json.load(sys.stdin)
    adapter = Copilot()
    adapter.ask(payload)


if __name__ == "__main__":
    main()
