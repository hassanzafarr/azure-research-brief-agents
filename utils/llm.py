"""Shared LLM config. Change the model or temperature here."""

import os
from langchain_anthropic import ChatAnthropic
from dotenv import load_dotenv

load_dotenv()


def get_llm(*, api_key: str | None = None):
    return ChatAnthropic(
        model="claude-haiku-4-5-20251001",
        temperature=0.3,
        max_tokens=2000,
        api_key=api_key if api_key is not None else os.getenv("ANTHROPIC_API_KEY"),
    )
