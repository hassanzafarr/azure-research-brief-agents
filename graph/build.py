"""
Graph wiring and routing. Defines the nodes, the edges between them, and
the conditional edge after the Critic that creates the research loop.
"""

from functools import partial

from langgraph.graph import StateGraph, END
from graph.state import ResearchState
from agents.researcher import researcher_node
from agents.critic import critic_node
from agents.writer import writer_node
from agents.editor import editor_node


def route_after_critic(state: ResearchState) -> str:
    """Pick the next node based on the Critic's verdict."""
    if state["is_approved"]:
        return "writer"
    return "researcher"  # loop back for another pass


def build_graph(*, anthropic_key: str | None = None, tavily_key: str | None = None):
    graph = StateGraph(ResearchState)

    graph.add_node(
        "researcher",
        partial(researcher_node, anthropic_key=anthropic_key, tavily_key=tavily_key),
    )
    graph.add_node("critic", partial(critic_node, anthropic_key=anthropic_key))
    graph.add_node("writer", partial(writer_node, anthropic_key=anthropic_key))
    graph.add_node("editor", partial(editor_node, anthropic_key=anthropic_key))

    graph.set_entry_point("researcher")

    graph.add_edge("researcher", "critic")

    # Conditional edge: approve -> writer, otherwise loop back.
    graph.add_conditional_edges(
        "critic",
        route_after_critic,
        {
            "researcher": "researcher",
            "writer": "writer",
        },
    )

    graph.add_edge("writer", "editor")
    graph.add_edge("editor", END)

    return graph.compile()
