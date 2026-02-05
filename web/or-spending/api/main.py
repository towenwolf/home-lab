from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import psycopg2
from psycopg2.extras import RealDictCursor
import os
from typing import List, Dict, Any

app = FastAPI(title="Oregon Tax Flow API", version="1.0.0")

# CORS for local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def get_db_connection():
    """Create database connection."""
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "dw-postgres"),
        port=os.getenv("POSTGRES_PORT", "5432"),
        database=os.getenv("POSTGRES_DB", "dw"),
        user=os.getenv("POSTGRES_USER", "analytics"),
        password=os.getenv("POSTGRES_PASSWORD"),
        cursor_factory=RealDictCursor,
    )


@app.get("/api/health")
def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


@app.get("/api/sankey/{fiscal_year}")
def get_sankey_data(
    fiscal_year: int, 
    top_agencies: int = 10
) -> Dict[str, Any]:
    """
    Get Sankey diagram data for a specific fiscal year.
    Returns nodes and links for D3 Sankey visualization.
    Shows flow from $1 Income Tax → General Fund → Top N Agencies.
    """
    try:
        conn = get_db_connection()
        cur = conn.cursor()

        # Get PIT share (percentage of income tax going to general fund)
        pit_share = 0.816  # 81.6%

        # Get top agencies for this fiscal year
        cur.execute("""
            SELECT agency_name, per_dollar, total_expense, pct_of_total
            FROM clean.int_spending_by_agency
            WHERE fiscal_year = %s
            ORDER BY total_expense DESC
            LIMIT %s
        """, (fiscal_year, top_agencies))
        
        top_agency_rows = cur.fetchall()
        top_agency_names = [row['agency_name'] for row in top_agency_rows]
        
        if not top_agency_names:
            raise HTTPException(status_code=404, detail=f"No data found for fiscal year {fiscal_year}")

        # Calculate "OTHER AGENCIES" value (remaining agencies not in top N)
        cur.execute("""
            SELECT SUM(per_dollar) as other_value, COUNT(*) as other_count
            FROM clean.int_spending_by_agency
            WHERE fiscal_year = %s AND agency_name != ALL(%s)
        """, (fiscal_year, top_agency_names))
        other_result = cur.fetchone()
        other_agencies_value = other_result['other_value'] or 0
        other_agencies_count = other_result['other_count'] or 0

        # Build links - only 2 layers now
        links_data = []
        
        # Layer 0→1: Your $1 Income Tax → General Fund
        links_data.append({
            'source': 'YOUR $1 INCOME TAX',
            'target': 'GENERAL FUND',
            'source_layer': 0,
            'target_layer': 1,
            'value': pit_share
        })

        # Layer 1→2: General Fund → Agencies
        for row in top_agency_rows:
            value = float(row['per_dollar']) * pit_share
            links_data.append({
                'source': 'GENERAL FUND',
                'target': row['agency_name'],
                'source_layer': 1,
                'target_layer': 2,
                'value': value
            })
        
        # Add "OTHER AGENCIES" if there are any
        if float(other_agencies_value) > 0:
            links_data.append({
                'source': 'GENERAL FUND',
                'target': f'OTHER AGENCIES ({other_agencies_count})',
                'source_layer': 1,
                'target_layer': 2,
                'value': float(other_agencies_value) * pit_share
            })

        # Get fiscal year totals
        cur.execute("""
            SELECT 
                fiscal_year,
                transaction_count,
                agency_count,
                vendor_count,
                grand_total
            FROM clean.int_fiscal_year_totals
            WHERE fiscal_year = %s
        """, (fiscal_year,))
        
        totals = cur.fetchone()
        
        # Get top agencies with their totals for summary
        cur.execute("""
            SELECT 
                agency_name,
                total_expense,
                pct_of_total
            FROM clean.int_spending_by_agency
            WHERE fiscal_year = %s
            ORDER BY total_expense DESC
            LIMIT %s
        """, (fiscal_year, top_agencies))
        
        top_agencies_data = cur.fetchall()

        conn.close()

        # Build nodes and links for D3
        node_map = {}
        nodes = []
        links = []

        def get_or_create_node(name: str, layer: int) -> int:
            key = f"{layer}:{name}"
            if key not in node_map:
                node_map[key] = len(nodes)
                nodes.append({"name": name, "layer": layer})
            return node_map[key]

        for row in links_data:
            source_idx = get_or_create_node(row['source'], row['source_layer'])
            target_idx = get_or_create_node(row['target'], row['target_layer'])
            links.append({
                "source": source_idx,
                "target": target_idx,
                "value": float(row['value'])
            })

        return {
            "fiscal_year": fiscal_year,
            "nodes": nodes,
            "links": links,
            "summary": {
                "grand_total": float(totals['grand_total']) if totals else 0,
                "transaction_count": totals['transaction_count'] if totals else 0,
                "agency_count": top_agencies,
                "top_agencies": [
                    {
                        "name": a['agency_name'],
                        "total": float(a['total_expense']),
                        "pct": float(a['pct_of_total']) * 100
                    }
                    for a in top_agencies_data
                ]
            }
        }

    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


@app.get("/api/fiscal-years")
def get_fiscal_years() -> List[int]:
    """Get available fiscal years."""
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT DISTINCT fiscal_year 
            FROM clean.int_fiscal_year_totals 
            ORDER BY fiscal_year DESC
        """)
        years = [row['fiscal_year'] for row in cur.fetchall()]
        conn.close()
        return years
    except psycopg2.Error as e:
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")


# Serve static files (HTML)
app.mount("/static", StaticFiles(directory="/app/static"), name="static")


@app.get("/")
def serve_index():
    """Serve the main HTML page."""
    return FileResponse("/app/static/index.html")
