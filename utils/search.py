"""Tavily search wrapper."""

import os
from tavily import TavilyClient
from dotenv import load_dotenv

load_dotenv()


def web_search(query: str, max_results: int = 5, *, api_key: str | None = None) -> str:
    client = TavilyClient(api_key=api_key if api_key is not None else os.getenv("TAVILY_API_KEY"))
    response = client.search(query=query, max_results=max_results)

    formatted = []
    for i, result in enumerate(response.get("results", []), 1):
        formatted.append(
            f"[Source {i}] {result['title']}\n"
            f"URL: {result['url']}\n"
            f"Content: {result['content']}\n"
        )

    return "\n".join(formatted) if formatted else "No results found."
