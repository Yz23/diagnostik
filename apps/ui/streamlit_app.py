import requests
import streamlit as st


API_URL = st.sidebar.text_input("API URL", "http://localhost:8000")
st.title("Diagnostik Community Platform")

if st.button("Health"):
    st.json(requests.get(f"{API_URL}/health", timeout=5).json())

if st.button("Run mock ingestion"):
    payload = {"workspace_id": "default", "dataset_id": "demo", "count": 12, "domain": "cybersecurity"}
    st.json(requests.post(f"{API_URL}/connectors/mock/runs", json=payload, timeout=10).json())

query = st.text_input("Search", "cybersecurity ai governance")
if st.button("Hybrid search"):
    payload = {"workspace_id": "default", "dataset_ids": ["demo"], "query": query, "search_type": "hybrid", "limit": 10}
    st.json(requests.post(f"{API_URL}/search/hybrid", json=payload, timeout=10).json())
