"""
Country Population Statistics — Streamlit Frontend
Refactored from the original vanilla JS/HTML app.

Configuration (via environment variables):
  API_HOST   — backend host  (default: localhost)
  API_PORT   — backend port  (default: 8000)
"""

import os
import requests
import streamlit as st

# ─── Config ────────────────────────────────────────────────────────────────────
LOCAL_API_HOST = os.environ.get("API_HOST", "localhost")
LOCAL_API_PORT = os.environ.get("API_PORT", "8000")
CLOUD_API_SERVER = os.environ.get("CLOUD_SERVER", None)
BASE_URL = f"http://{LOCAL_API_HOST}:{LOCAL_API_PORT}" if not CLOUD_API_SERVER else f"{CLOUD_API_SERVER}"
COUNTRIES_PATH = "/countries"

PAGE_SIZE_CODE = 20
PAGE_SIZE_YEAR = 40
PAGE_SIZE_ALL  = 50

# ─── Page setup ────────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Country Population Statistics",
    page_icon="🌍",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ─── Custom CSS ────────────────────────────────────────────────────────────────
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Syne:wght@400;600;700;800&family=DM+Mono:wght@300;400;500&display=swap');

/* ── Root tokens ── */
:root {
    --bg:        #0d1117;
    --surface:   #161b22;
    --surface2:  #1c2330;
    --border:    #30363d;
    --accent:    #3fb950;
    --accent2:   #58a6ff;
    --accent3:   #f78166;
    --text:      #e6edf3;
    --muted:     #7d8590;
    --radius:    10px;
}

/* ── Global ── */
html, body, [class*="css"] {
    font-family: 'DM Mono', monospace;
    background-color: var(--bg) !important;
    color: var(--text) !important;
}

/* ── Hide Streamlit chrome ── */
#MainMenu, footer, header { visibility: hidden; }
.block-container { padding-top: 2rem !important; max-width: 100% !important; }

/* ── Custom header ── */
.app-header {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 24px 32px 16px;
    border-bottom: 1px solid var(--border);
    margin-bottom: 28px;
}
.app-header .globe { font-size: 2.6rem; line-height: 1; }
.app-header h1 {
    font-family: 'Syne', sans-serif;
    font-size: 2rem;
    font-weight: 800;
    margin: 0;
    letter-spacing: -0.03em;
    background: linear-gradient(90deg, var(--accent) 0%, var(--accent2) 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    background-clip: text;
}
.app-header .subtitle {
    font-size: 0.78rem;
    color: var(--muted);
    letter-spacing: 0.08em;
    text-transform: uppercase;
    margin-top: 2px;
}

/* ── Sidebar ── */
[data-testid="stSidebar"] {
    background-color: var(--surface) !important;
    border-right: 1px solid var(--border) !important;
}
[data-testid="stSidebar"] .sidebar-section-title {
    font-family: 'Syne', sans-serif;
    font-size: 0.7rem;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    color: var(--muted);
    margin-bottom: 12px;
    padding-bottom: 6px;
    border-bottom: 1px solid var(--border);
}

/* ── Streamlit input overrides ── */
[data-testid="stTextInput"] input {
    background: var(--surface2) !important;
    border: 1px solid var(--border) !important;
    border-radius: var(--radius) !important;
    color: var(--text) !important;
    font-family: 'DM Mono', monospace !important;
    font-size: 0.9rem !important;
}
[data-testid="stTextInput"] input:focus {
    border-color: var(--accent2) !important;
    box-shadow: 0 0 0 3px rgba(88,166,255,0.15) !important;
}

/* ── Buttons ── */
.stButton > button {
    font-family: 'Syne', sans-serif !important;
    font-weight: 700 !important;
    font-size: 0.82rem !important;
    letter-spacing: 0.05em !important;
    border-radius: var(--radius) !important;
    transition: all 0.18s ease !important;
    border: none !important;
    width: 100% !important;
}
.stButton > button:first-child {
    background: linear-gradient(135deg, var(--accent) 0%, #2ea043 100%) !important;
    color: #0d1117 !important;
}
.stButton > button:hover {
    transform: translateY(-1px) !important;
    box-shadow: 0 4px 16px rgba(63,185,80,0.3) !important;
}

/* ── Stat cards ── */
.stat-row {
    display: flex;
    gap: 16px;
    margin-bottom: 24px;
    flex-wrap: wrap;
}
.stat-card {
    flex: 1;
    min-width: 140px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    padding: 16px 20px;
    position: relative;
    overflow: hidden;
}
.stat-card::before {
    content: '';
    position: absolute;
    top: 0; left: 0; right: 0;
    height: 2px;
}
.stat-card.green::before  { background: var(--accent); }
.stat-card.blue::before   { background: var(--accent2); }
.stat-card.orange::before { background: var(--accent3); }
.stat-card.purple::before { background: #bc8cff; }

.stat-card .label {
    font-size: 0.68rem;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--muted);
    margin-bottom: 6px;
}
.stat-card .value {
    font-family: 'Syne', sans-serif;
    font-size: 1.5rem;
    font-weight: 800;
    color: var(--text);
}

/* ── Data table ── */
.data-table-wrapper {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    overflow: hidden;
    margin-bottom: 20px;
}
.data-table-wrapper table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.88rem;
}
.data-table-wrapper thead tr {
    background: var(--surface2);
    border-bottom: 2px solid var(--border);
}
.data-table-wrapper thead th {
    padding: 13px 18px;
    text-align: left;
    font-family: 'Syne', sans-serif;
    font-size: 0.7rem;
    font-weight: 700;
    letter-spacing: 0.1em;
    text-transform: uppercase;
    color: var(--muted);
}
.data-table-wrapper tbody tr {
    border-bottom: 1px solid var(--border);
    transition: background 0.12s;
}
.data-table-wrapper tbody tr:last-child { border-bottom: none; }
.data-table-wrapper tbody tr:hover { background: var(--surface2); }
.data-table-wrapper tbody td {
    padding: 12px 18px;
    color: var(--text);
}
.data-table-wrapper tbody td.code-cell {
    font-family: 'DM Mono', monospace;
    font-size: 0.8rem;
    color: var(--accent2);
    font-weight: 500;
}
.data-table-wrapper tbody td.year-cell {
    color: var(--accent3);
    font-weight: 500;
}
.data-table-wrapper tbody td.pop-cell {
    color: var(--accent);
    font-weight: 500;
    text-align: right;
}
.data-table-wrapper thead th:last-child { text-align: right; }

/* ── Pagination bar ── */
.pagination-info {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 16px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    margin-bottom: 16px;
    font-size: 0.8rem;
    color: var(--muted);
}
.pagination-info .page-tag {
    font-family: 'Syne', sans-serif;
    font-weight: 700;
    font-size: 0.85rem;
    color: var(--accent2);
}

/* ── Error card ── */
.error-card {
    background: rgba(247,129,102,0.08);
    border: 1px solid var(--accent3);
    border-radius: var(--radius);
    padding: 20px 24px;
    margin-top: 12px;
}
.error-card .err-title {
    font-family: 'Syne', sans-serif;
    font-weight: 700;
    font-size: 1rem;
    color: var(--accent3);
    margin-bottom: 8px;
}
.error-card .err-detail { font-size: 0.85rem; color: var(--muted); line-height: 1.6; }

/* ── API config badge ── */
.api-badge {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    background: var(--surface2);
    border: 1px solid var(--border);
    border-radius: 999px;
    padding: 4px 12px;
    font-size: 0.72rem;
    color: var(--muted);
    font-family: 'DM Mono', monospace;
    margin-bottom: 20px;
}
.api-badge .dot {
    width: 7px; height: 7px;
    border-radius: 50%;
    background: var(--accent);
    box-shadow: 0 0 6px var(--accent);
}

/* ── Filter mode tag ── */
.mode-tag {
    display: inline-block;
    font-family: 'Syne', sans-serif;
    font-size: 0.65rem;
    font-weight: 700;
    letter-spacing: 0.12em;
    text-transform: uppercase;
    padding: 2px 10px;
    border-radius: 999px;
    margin-bottom: 16px;
}
.mode-tag.all    { background: rgba(63,185,80,0.15);  color: var(--accent); }
.mode-tag.code   { background: rgba(88,166,255,0.15); color: var(--accent2); }
.mode-tag.year   { background: rgba(247,129,102,0.15);color: var(--accent3); }
.mode-tag.init   { background: rgba(188,140,255,0.15);color: #bc8cff; }

/* ── Empty state ── */
.empty-state {
    text-align: center;
    padding: 64px 32px;
    color: var(--muted);
}
.empty-state .icon { font-size: 3rem; margin-bottom: 12px; }
.empty-state p { font-size: 0.9rem; }

/* ── Divider ── */
hr { border-color: var(--border) !important; margin: 20px 0 !important; }
</style>
""", unsafe_allow_html=True)


# ─── Session state ─────────────────────────────────────────────────────────────
def _init_state():
    defaults = {
        "data":       None,
        "links":      {},
        "error":      None,
        "mode":       None,   # "init" | "all" | "code" | "year"
        "mode_value": None,
        "page_url":   None,
    }
    for k, v in defaults.items():
        if k not in st.session_state:
            st.session_state[k] = v

_init_state()


# ─── API helpers ───────────────────────────────────────────────────────────────
def _fetch(url: str):
    """GET url, store result in session_state."""
    try:
        r = requests.get(url, timeout=10)
        if r.status_code == 200:
            body = r.json()
            st.session_state.data   = body.get("items", [])
            st.session_state.links  = body.get("links", {})
            st.session_state.error  = None
            st.session_state.page_url = url
        else:
            try:
                err = r.json()
            except Exception:
                err = {"statusCode": r.status_code, "message": r.text, "status": "ERROR"}
            st.session_state.error  = err
            st.session_state.data   = None
            st.session_state.links  = {}
    except requests.exceptions.ConnectionError:
        st.session_state.error  = {
            "statusCode": 0,
            "status": "CONNECTION ERROR",
            "message": f"Cannot reach {BASE_URL}. Is the backend running?",
        }
        st.session_state.data   = None
        st.session_state.links  = {}


def _url_all(page=1):
    return f"{BASE_URL}{COUNTRIES_PATH}?page={page}&size={PAGE_SIZE_ALL}"

def _url_init(page=1):
    return f"{BASE_URL}{COUNTRIES_PATH}/save?page={page}&size={PAGE_SIZE_ALL}"

def _url_code(code, page=1):
    return f"{BASE_URL}{COUNTRIES_PATH}/code/{code}?page={page}&size={PAGE_SIZE_CODE}"

def _url_year(year, page=1):
    return f"{BASE_URL}{COUNTRIES_PATH}/year/{year}?page={page}&size={PAGE_SIZE_YEAR}"


# ─── Header ────────────────────────────────────────────────────────────────────
st.markdown(f"""
<div class="app-header">
    <div class="globe">🌍</div>
    <div>
        <h1>Country Population Statistics</h1>
        <div class="subtitle">World Bank Dataset &nbsp;·&nbsp; Historical Records</div>
    </div>
</div>
<div style="padding: 0 32px;">
    <span class="api-badge">
        <span class="dot"></span>
        {BASE_URL}{COUNTRIES_PATH}
    </span>
</div>
""", unsafe_allow_html=True)


# ─── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown("## 🔎 Filters")
    st.markdown("---")

    # ── Init / load data ──
    st.markdown('<div class="sidebar-section-title">Data Initialisation</div>', unsafe_allow_html=True)
    if st.button("⬇️  Load & Save Countries", key="btn_init"):
        st.session_state.mode       = "init"
        st.session_state.mode_value = None
        _fetch(_url_init())
    st.markdown("---")

    # ── Show all ──
    st.markdown('<div class="sidebar-section-title">Browse</div>', unsafe_allow_html=True)
    if st.button("🌐  Show All Countries", key="btn_all"):
        st.session_state.mode       = "all"
        st.session_state.mode_value = None
        _fetch(_url_all())
    st.markdown("---")

    # ── Filter by code ──
    st.markdown('<div class="sidebar-section-title">Filter by Country Code</div>', unsafe_allow_html=True)
    code_input = st.text_input("Country Code", placeholder="e.g. HUN, USA, DEU", key="code_input", label_visibility="collapsed")
    if st.button("🔍  Search by Code", key="btn_code"):
        if not code_input.strip():
            st.warning("Please enter a country code.")
        else:
            st.session_state.mode       = "code"
            st.session_state.mode_value = code_input.strip().upper()
            _fetch(_url_code(st.session_state.mode_value))
    st.markdown("---")

    # ── Filter by year ──
    st.markdown('<div class="sidebar-section-title">Filter by Year</div>', unsafe_allow_html=True)
    year_input = st.text_input("Year", placeholder="e.g. 1990  (1960–2010)", key="year_input", label_visibility="collapsed")
    if st.button("🔍  Search by Year", key="btn_year"):
        if not year_input.strip():
            st.warning("Please enter a year.")
        else:
            try:
                yr = int(year_input.strip())
                st.session_state.mode       = "year"
                st.session_state.mode_value = yr
                _fetch(_url_year(yr))
            except ValueError:
                st.error("Year must be a number (e.g. 1990).")
    st.markdown("---")

    # ── API config ──
    st.markdown('<div class="sidebar-section-title">API Configuration</div>', unsafe_allow_html=True)
    st.code(f"HOST: {API_HOST}\nPORT: {API_PORT}", language="text")
    st.caption("Set via `API_HOST` / `API_PORT` env vars.")


# ─── Main content ───────────────────────────────────────────────────────────────
main = st.container()

with main:
    pad_l, col, pad_r = st.columns([0.03, 0.94, 0.03])
    with col:

        # ── No data yet ──
        if st.session_state.data is None and st.session_state.error is None:
            st.markdown("""
            <div class="empty-state">
                <div class="icon">🌐</div>
                <p>Use the sidebar to load or search country population data.</p>
            </div>
            """, unsafe_allow_html=True)

        # ── Error state ──
        elif st.session_state.error:
            err = st.session_state.error
            st.markdown(f"""
            <div class="error-card">
                <div class="err-title">⚠️ {err.get('status', 'Error')}</div>
                <div class="err-detail">
                    <b>Status code:</b> {err.get('statusCode', '—')}<br>
                    <b>Message:</b> {err.get('message', 'Unknown error')}
                </div>
            </div>
            """, unsafe_allow_html=True)

        # ── Data state ──
        else:
            items = st.session_state.data or []
            links = st.session_state.links or {}
            mode  = st.session_state.mode

            # Mode tag
            mode_labels = {
                "init": ("init",  "⬇️ Data loaded & saved"),
                "all":  ("all",   "🌐 All countries"),
                "code": ("code",  f"🔍 Code: {st.session_state.mode_value}"),
                "year": ("year",  f"📅 Year: {st.session_state.mode_value}"),
            }
            if mode in mode_labels:
                cls, label = mode_labels[mode]
                st.markdown(f'<span class="mode-tag {cls}">{label}</span>', unsafe_allow_html=True)

            # ── Stat cards ──
            total   = len(items)
            codes   = len({r.get("country_code") for r in items})
            years   = len({r.get("year") for r in items})
            max_pop = max((int(float(r.get("population", 0))) for r in items), default=0)

            st.markdown(f"""
            <div class="stat-row">
                <div class="stat-card green">
                    <div class="label">Records</div>
                    <div class="value">{total:,}</div>
                </div>
                <div class="stat-card blue">
                    <div class="label">Countries</div>
                    <div class="value">{codes:,}</div>
                </div>
                <div class="stat-card orange">
                    <div class="label">Years</div>
                    <div class="value">{years:,}</div>
                </div>
                <div class="stat-card purple">
                    <div class="label">Max Population</div>
                    <div class="value">{max_pop:,}</div>
                </div>
            </div>
            """, unsafe_allow_html=True)

            # ── Pagination info ──
            has_first = bool(links.get("first"))
            has_prev  = bool(links.get("prev"))
            has_next  = bool(links.get("next"))
            has_last  = bool(links.get("last"))

            at_start = not has_first and not has_prev
            at_end   = not has_next  and not has_last

            if at_start and at_end:
                page_tag = "Single page"
            elif at_start:
                page_tag = "Page 1"
            elif at_end:
                page_tag = "Last page"
            else:
                page_tag = "Page …"

            st.markdown(f"""
            <div class="pagination-info">
                <span>Showing <b>{total}</b> records in this page</span>
                <span class="page-tag">{page_tag}</span>
            </div>
            """, unsafe_allow_html=True)

            # ── Pagination buttons ──
            pc1, pc2, pc3, pc4 = st.columns(4)

            with pc1:
                if st.button("⏮ First", disabled=not has_first, key="pg_first"):
                    url = BASE_URL + links["first"]
                    _fetch(url)
                    st.rerun()

            with pc2:
                if st.button("◀ Prev", disabled=not has_prev, key="pg_prev"):
                    url = BASE_URL + links["prev"]
                    _fetch(url)
                    st.rerun()

            with pc3:
                if st.button("Next ▶", disabled=not has_next, key="pg_next"):
                    url = BASE_URL + links["next"]
                    _fetch(url)
                    st.rerun()

            with pc4:
                if st.button("Last ⏭", disabled=not has_last, key="pg_last"):
                    url = BASE_URL + links["last"]
                    _fetch(url)
                    st.rerun()

            st.markdown("<div style='height:12px'></div>", unsafe_allow_html=True)

            # ── Data table ──
            if items:
                rows_html = ""
                for row in items:
                    name = row.get("country_name", "—")
                    code = row.get("country_code", "—")
                    year = row.get("year", "—")
                    pop  = int(float(row.get("population", 0)))
                    rows_html += (
                        f"<tr>"
                        f"<td>{name}</td>"
                        f"<td class='code-cell'>{code}</td>"
                        f"<td class='year-cell'>{year}</td>"
                        f"<td class='pop-cell'>{pop:,}</td>"
                        f"</tr>"
                )

                table_html = (
                   "<div class='data-table-wrapper'>"
                   "<table><thead><tr>"
                   "<th>Country Name</th><th>Code</th><th>Year</th><th>Population</th>"
                   "</tr></thead>"
                   f"<tbody>{rows_html}</tbody>"
                   "</table></div>"
                )
                st.markdown(table_html, unsafe_allow_html=True)