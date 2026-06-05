"""
Minimal MCP client for testing the TEDx server.
Ignores SSL verification — for use with self-signed certs only.
University lesson demo - unibg_tedx_2026
"""

import asyncio
import urllib3
import httpx
from mcp import ClientSession
from mcp.client.streamable_http import streamablehttp_client

SERVER_URL = "https://44.201.141.192:8443/mcp"

# Suppress InsecureRequestWarning
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


def insecure_httpx_client(headers=None, timeout=None, auth=None):
    """httpx client that skips SSL verification (demo only!)."""
    return httpx.AsyncClient(
        headers=headers,
        timeout=timeout if timeout else httpx.Timeout(30.0),
        auth=auth,
        verify=False,
        follow_redirects=True,
    )


def print_section(title: str):
    print(f"\n{'='*50}")
    print(f"  {title}")
    print(f"{'='*50}")


def print_result(result):
    for item in result.content:
        print(item.text)


async def main():
    async with streamablehttp_client(
        SERVER_URL,
        httpx_client_factory=insecure_httpx_client,
    ) as (read, write, _):
        async with ClientSession(read, write) as session:

            # 1. Connessione
            await session.initialize()
            print("✓ Connected to TEDx MCP server")

            # 2. Lista tool disponibili
            print_section("Available Tools")
            tools = await session.list_tools()
            for t in tools.tools:
                print(f"  • {t.name} — {t.description}")

            # 3. top_tags
            print_section("top_tags(limit=5)")
            result = await session.call_tool("top_tags", arguments={"limit": 5})
            print_result(result)

            # 4. search_by_tag
            print_section("search_by_tag(tag='technology', limit=3)")
            result = await session.call_tool(
                "search_by_tag",
                arguments={"tag": "technology", "limit": 3},
            )
            print_result(result)

            # 5. search_by_keyword
            print_section("search_by_keyword(keyword='artificial intelligence', limit=3)")
            result = await session.call_tool(
                "search_by_keyword",
                arguments={"keyword": "artificial intelligence", "limit": 3},
            )
            print_result(result)

            # 6. search_by_speaker
            print_section("search_by_speaker(speaker='Brené Brown', limit=3)")
            result = await session.call_tool(
                "search_by_speaker",
                arguments={"speaker": "Brené Brown", "limit": 3},
            )
            print_result(result)

            # 7. semantic_search
            print_section("semantic_search(query='overcoming fear and anxiety', n_results=3)")
            result = await session.call_tool(
                "semantic_search",
                arguments={"query": "overcoming fear and anxiety", "n_results": 3},
            )
            print_result(result)

            # 8. get_talk — usa uno slug reale dal tuo DB
            print_section("get_talk(slug='...')")
            print("  ⚠ Inserisci uno slug reale dal tuo MongoDB per testare questo tool.")
            # result = await session.call_tool(
            #     "get_talk",
            #     arguments={"slug": "brene_brown_the_power_of_vulnerability"},
            # )
            # print_result(result)

            print("\n✓ Tutti i test completati.\n")


if __name__ == "__main__":
    asyncio.run(main())