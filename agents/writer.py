"""
Writer: turns the approved research notes into a structured brief.
"""

from graph.state import ResearchState
from utils.llm import get_llm
from langchain_core.messages import HumanMessage


def writer_node(state: ResearchState, *, anthropic_key: str | None = None) -> dict:
    topic = state["topic"]
    all_notes = "\n\n".join(state["research_notes"])

    print("[Writer] Drafting final brief")

    llm = get_llm(api_key=anthropic_key)

    write_prompt = (
        f"Topic: {topic}\n"
        f"Approved research notes:\n{all_notes}\n\n"
        f"Write a clear, well-structured brief on this topic using only "
        f"the research above. Use a short intro, 3-5 key points with "
        f"brief explanations, and a one-sentence takeaway at the end. "
        f"Keep it tight and readable, not bloated."
    )

    response = llm.invoke([HumanMessage(content=write_prompt)])
    brief = response.content.strip()

    print(f"[Writer] Done.\n")

    return {"final_brief": brief}
