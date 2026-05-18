#!/usr/bin/env python3
"""
MCP Server for searching nixos-unified.org documentation.

Provides tools for:
- Searching documentation pages
- Getting specific page content
- Finding examples and patterns
"""

import json
import sys
import requests
from bs4 import BeautifulSoup
import re
from urllib.parse import urljoin, urlparse

# Base URL for nixos-unified.org
BASE_URL = "https://nixos-unified.org"

# Cache for documentation pages
_doc_cache = {}

def send_message(msg: dict):
    """Send a JSON-RPC message to stdout."""
    json_str = json.dumps(msg)
    sys.stdout.write(f"Content-Length: {len(json_str)}\r\n\r\n{json_str}")
    sys.stdout.flush()

def read_message():
    """Read a JSON-RPC message from stdin."""
    headers = {}
    while True:
        line = sys.stdin.readline()
        if line == "\r\n":
            break
        if line == "":
            return None
        if ":" in line:
            key, value = line.split(":", 1)
            headers[key.strip()] = value.strip()
    
    if "Content-Length" not in headers:
        return None
    
    length = int(headers["Content-Length"])
    body = sys.stdin.read(length)
    return json.loads(body)

def fetch_page(url: str) -> str:
    """Fetch a page from nixos-unified.org with caching."""
    if url in _doc_cache:
        return _doc_cache[url]
    
    try:
        response = requests.get(url, timeout=10)
        response.raise_for_status()
        content = response.text
        _doc_cache[url] = content
        return content
    except Exception as e:
        return f"Error fetching {url}: {str(e)}"

def search_docs(query: str) -> list:
    """Search documentation for a query."""
    results = []
    
    # Fetch main pages
    pages = [
        "/",
        "/getting-started",
        "/autowiring",
        "/configurations",
        "/modules",
        "/secrets",
        "/faq",
    ]
    
    for page in pages:
        url = urljoin(BASE_URL, page)
        content = fetch_page(url)
        
        if content.startswith("Error"):
            continue
        
        soup = BeautifulSoup(content, 'html.parser')
        text = soup.get_text()
        
        # Check if query is in page content
        if query.lower() in text.lower():
            # Extract title
            title = soup.title.string if soup.title else page
            
            # Extract snippet around query
            snippet = extract_snippet(text, query)
            
            results.append({
                "title": title,
                "url": url,
                "snippet": snippet
            })
    
    return results

def extract_snippet(text: str, query: str, context: int = 100) -> str:
    """Extract a snippet of text around the query match."""
    text = re.sub(r'\s+', ' ', text)  # Normalize whitespace
    query_lower = query.lower()
    idx = text.lower().find(query_lower)
    
    if idx == -1:
        return text[:200] + "..."
    
    start = max(0, idx - context)
    end = min(len(text), idx + len(query) + context)
    
    snippet = text[start:end]
    
    # Add ellipsis if truncated
    if start > 0:
        snippet = "..." + snippet
    if end > len(text):
        snippet = snippet + "..."
    
    return snippet

def get_page_content(url_path: str) -> str:
    """Get full content of a specific documentation page."""
    url = urljoin(BASE_URL, url_path)
    content = fetch_page(url)
    
    if content.startswith("Error"):
        return content
    
    soup = BeautifulSoup(content, 'html.parser')
    
    # Extract main content
    main_content = soup.find('main') or soup.find('article') or soup.find('div', class_='content')
    
    if main_content:
        text = main_content.get_text(separator='\n', strip=True)
    else:
        text = soup.get_text(separator='\n', strip=True)
    
    # Clean up the text
    lines = [line.strip() for line in text.split('\n') if line.strip()]
    return '\n'.join(lines[:100])  # Limit to first 100 lines

# Tool definitions
TOOLS = [
    {
        "name": "search_nixos_unified",
        "description": "Search nixos-unified.org documentation for a query",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Search query (e.g., 'autowiring', 'profiles', 'secrets')"
                }
            },
            "required": ["query"]
        }
    },
    {
        "name": "get_page",
        "description": "Get content of a specific nixos-unified.org documentation page",
        "inputSchema": {
            "type": "object",
            "properties": {
                "path": {
                    "type": "string",
                    "description": "Page path (e.g., '/getting-started', '/autowiring')",
                    "default": "/"
                }
            },
            "required": ["path"]
        }
    },
    {
        "name": "find_examples",
        "description": "Find configuration examples in the documentation",
        "inputSchema": {
            "type": "object",
            "properties": {
                "topic": {
                    "type": "string",
                    "description": "Topic to find examples for (e.g., 'workstation', 'server', 'wsl')"
                }
            },
            "required": ["topic"]
        }
    }
]

def handle_search(params: dict) -> dict:
    """Handle search_nixos_unified tool."""
    query = params.get("query", "")
    
    if not query:
        return {
            "content": [{"type": "text", "text": "Error: query is required"}],
            "isError": True
        }
    
    results = search_docs(query)
    
    if not results:
        return {
            "content": [{"type": "text", "text": f"No results found for '{query}'"}],
            "isError": False
        }
    
    output = f"Found {len(results)} result(s) for '{query}':\n\n"
    for i, result in enumerate(results, 1):
        output += f"{i}. {result['title']}\n"
        output += f"   URL: {result['url']}\n"
        output += f"   {result['snippet']}\n\n"
    
    return {
        "content": [{"type": "text", "text": output}],
        "isError": False
    }

def handle_get_page(params: dict) -> dict:
    """Handle get_page tool."""
    path = params.get("path", "/")
    
    content = get_page_content(path)
    
    if content.startswith("Error"):
        return {
            "content": [{"type": "text", "text": content}],
            "isError": True
        }
    
    url = urljoin(BASE_URL, path)
    output = f"Content from {url}:\n\n{content}"
    
    return {
        "content": [{"type": "text", "text": output}],
        "isError": False
    }

def handle_find_examples(params: dict) -> dict:
    """Handle find_examples tool."""
    topic = params.get("topic", "")
    
    # Search for examples in the documentation
    query = f"{topic} example"
    results = search_docs(query)
    
    # Also search for configuration patterns
    config_results = search_docs(f"{topic} configuration")
    
    all_results = results + [r for r in config_results if r not in results]
    
    if not all_results:
        return {
            "content": [{"type": "text", "text": f"No examples found for '{topic}'"}],
            "isError": False
        }
    
    output = f"Found examples for '{topic}':\n\n"
    for i, result in enumerate(all_results[:5], 1):  # Limit to top 5
        output += f"{i}. {result['title']}\n"
        output += f"   URL: {result['url']}\n"
        output += f"   {result['snippet']}\n\n"
    
    return {
        "content": [{"type": "text", "text": output}],
        "isError": False
    }

def handle_tool_call(name: str, params: dict) -> dict:
    """Route tool calls to appropriate handlers."""
    handlers = {
        "search_nixos_unified": handle_search,
        "get_page": handle_get_page,
        "find_examples": handle_find_examples,
    }
    
    handler = handlers.get(name)
    if handler:
        return handler(params)
    else:
        return {
            "content": [{"type": "text", "text": f"Unknown tool: {name}"}],
            "isError": True
        }

def main():
    """Main entry point - MCP protocol handler."""
    # Send initialization response
    init_response = {
        "jsonrpc": "2.0",
        "id": 1,
        "result": {
            "protocolVersion": "2024-11-05",
            "serverInfo": {
                "name": "mcp-nixos-docs",
                "version": "0.1.0"
            },
            "capabilities": {
                "tools": {}
            }
        }
    }
    send_message(init_response)
    
    # Main loop
    while True:
        msg = read_message()
        if msg is None:
            break
        
        method = msg.get("method", "")
        msg_id = msg.get("id")
        
        if method == "tools/list":
            response = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {"tools": TOOLS}
            }
            send_message(response)
        
        elif method == "tools/call":
            params = msg.get("params", {})
            tool_name = params.get("name", "")
            tool_params = params.get("arguments", {})
            
            result = handle_tool_call(tool_name, tool_params)
            response = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": result
            }
            send_message(response)
        
        elif method == "initialize":
            response = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "serverInfo": {
                        "name": "mcp-nixos-docs",
                        "version": "0.1.0"
                    },
                    "capabilities": {
                        "tools": {}
                    }
                }
            }
            send_message(response)

if __name__ == "__main__":
    main()
