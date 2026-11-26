import os
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from langchain_core.messages import AIMessage
from streamlit.testing.v1 import AppTest

APP_PATH = Path(__file__).resolve().parents[1] / "app.py"


class ResearchAppTests(unittest.TestCase):
    def test_requires_a_topic_and_both_provider_keys(self):
        app = AppTest.from_file(APP_PATH).run()
        app.button[0].click().run()
        self.assertEqual(app.error[0].value, "Enter a topic.")

        app.main.text_input[0].set_value("Container Apps")
        app.sidebar.text_input[0].set_value("visitor-anthropic")
        app.button[0].click().run()
        self.assertIn("Anthropic and Tavily API keys", app.warning[0].value)

    @patch("utils.search.TavilyClient")
    @patch("utils.llm.ChatAnthropic")
    def test_research_retries_and_uses_only_the_visitors_keys(self, anthropic, tavily):
        responses = [
            "container apps basics",
            "First-pass notes",
            "VERDICT: NEEDS_MORE\nFEEDBACK: Include scaling behavior.",
            "container apps scale to zero",
            "Second-pass notes",
            "VERDICT: APPROVED\nFEEDBACK: none",
            "Draft brief",
            "Polished brief\nEDITOR_NOTE: Tightened the wording.",
        ]
        llm = Mock()
        llm.invoke.side_effect = [AIMessage(content=reply) for reply in responses]
        anthropic.return_value = llm
        tavily.return_value.search.return_value = {
            "results": [
                {"title": "Azure docs", "url": "https://learn.microsoft.com/", "content": "Example"}
            ]
        }

        with patch.dict(
            os.environ,
            {"ANTHROPIC_API_KEY": "process-anthropic", "TAVILY_API_KEY": "process-tavily"},
        ):
            app = AppTest.from_file(APP_PATH).run()
            app.sidebar.text_input[0].set_value("visitor-anthropic")
            app.sidebar.text_input[1].set_value("visitor-tavily")
            app.main.text_input[0].set_value("Azure Container Apps")
            app.button[0].click().run(timeout=15)

            self.assertEqual(os.environ["ANTHROPIC_API_KEY"], "process-anthropic")
            self.assertEqual(os.environ["TAVILY_API_KEY"], "process-tavily")

        self.assertFalse(app.exception)
        self.assertFalse(app.error)
        self.assertIn("Polished brief", [item.value for item in app.markdown])
        self.assertEqual(llm.invoke.call_count, len(responses))
        anthropic_keys = [call.kwargs["api_key"] for call in anthropic.call_args_list]
        self.assertEqual(anthropic_keys, ["visitor-anthropic"] * 6)
        tavily_keys = [call.kwargs["api_key"] for call in tavily.call_args_list]
        self.assertEqual(tavily_keys, ["visitor-tavily"] * 2)
        queries = [call.kwargs["query"] for call in tavily.return_value.search.call_args_list]
        self.assertEqual(queries, ["container apps basics", "container apps scale to zero"])


if __name__ == "__main__":
    unittest.main()
