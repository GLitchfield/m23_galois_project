#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
import threading
import time
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

from m23_run_status import collect_run_status


PAGE = r"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>M23 search monitor</title>
  <style>
    :root { color-scheme: dark; --bg:#0b1018; --panel:#131b27; --line:#263448;
      --text:#e6edf5; --muted:#91a0b5; --blue:#6db5ff; --green:#64d69b;
      --yellow:#f0c66a; --red:#ff7b7b; }
    * { box-sizing:border-box } body { margin:0; background:var(--bg); color:var(--text);
      font:14px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace }
    header { padding:24px clamp(18px,4vw,52px); border-bottom:1px solid var(--line);
      display:flex; justify-content:space-between; gap:20px; align-items:end }
    h1 { margin:0; font:600 clamp(22px,3vw,34px)/1.1 system-ui,sans-serif }
    .subtitle,.muted { color:var(--muted) } main { padding:24px clamp(18px,4vw,52px) 50px }
    .summary { display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr));
      gap:12px; margin-bottom:22px }.metric,.run { background:var(--panel);
      border:1px solid var(--line); border-radius:10px }.metric { padding:14px }
    .metric b { display:block; font-size:24px; color:var(--blue) }
    .overall { background:var(--panel); border:1px solid var(--line); border-radius:12px;
      padding:20px; margin-bottom:18px }.overall h2 { margin:0; font:600 20px system-ui,sans-serif }
    .overall-head { display:flex; justify-content:space-between; align-items:start; gap:18px;
      margin-bottom:16px }.overall-grid { display:grid;
      grid-template-columns:repeat(auto-fit,minmax(145px,1fr)); gap:10px; margin-top:16px }
    .overall-stat { padding:11px 12px; background:#0d141f; border-radius:8px }
    .overall-stat span { display:block; color:var(--muted); font-size:12px }
    .overall-stat b { display:block; margin-top:3px; font-size:18px }
    .coverage-label { display:flex; justify-content:space-between; gap:15px; margin-bottom:7px }
    .coverage { position:relative; height:18px; background:#080d14; border:1px solid var(--line);
      border-radius:10px; overflow:hidden }.coverage i { position:absolute; inset:0 auto 0 0 }
    .coverage .scanned { background:#245e92 }.coverage .checkpoint { background:#9b772c }
    .coverage .verified { background:#28704e }.legend { display:flex; flex-wrap:wrap;
      gap:12px; margin-top:8px; color:var(--muted); font-size:12px }.legend i { width:10px;
      height:10px; border-radius:2px; display:inline-block; margin-right:5px }
    .wave { margin-top:17px }.wave .bar { height:10px }.wave .bar i { background:var(--blue) }
    .runs { display:grid; gap:16px }.run { overflow:hidden }.run-head { padding:16px 18px;
      display:flex; align-items:center; justify-content:space-between; gap:16px; cursor:pointer }
    .run h2 { margin:0 0 3px; font:600 18px system-ui,sans-serif }.path { color:var(--muted);
      font-size:12px; overflow-wrap:anywhere }.badge { border:1px solid currentColor;
      border-radius:99px; padding:4px 9px; text-transform:uppercase; font-size:11px }
    .running { color:var(--blue) }.complete { color:var(--green) }.failed { color:var(--red) }
    .stopped,.idle,.paused { color:var(--yellow) }.details { border-top:1px solid var(--line);
      padding:18px; display:grid; gap:18px }.phase-grid { display:grid;
      grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:12px }.phase label {
      display:flex; justify-content:space-between; color:var(--muted); margin-bottom:5px }
    .bar { height:8px; background:#09101a; border-radius:8px; overflow:hidden }.bar i {
      display:block; height:100%; background:var(--blue); transition:width .25s }
    .facts { display:grid; grid-template-columns:repeat(auto-fit,minmax(190px,1fr)); gap:8px }
    .facts div { color:var(--muted) }.facts b { color:var(--text) }
    table { width:100%; border-collapse:collapse; font-size:12px } th,td { text-align:left;
      padding:7px 8px; border-bottom:1px solid var(--line); vertical-align:top } th { color:var(--muted) }
    .log { margin:0; padding:12px; max-height:300px; overflow:auto; background:#080d14;
      border:1px solid var(--line); white-space:pre-wrap; color:#b9c8da }.error { color:var(--red) }
    button { font:inherit; color:var(--blue); background:transparent; border:1px solid var(--line);
      border-radius:6px; padding:6px 9px; cursor:pointer } @media(max-width:650px){header{align-items:start;
      flex-direction:column}.run-head{align-items:start}.events th:nth-child(1),.events td:nth-child(1){display:none}}
  </style>
</head>
<body><header><div><h1>M23 search monitor</h1><div class="subtitle">Read-only view of durable run state</div></div>
  <div id="updated" class="muted">connecting…</div></header><main>
  <div id="notice"></div><section id="overall"></section><section id="summary" class="summary"></section><section id="runs" class="runs"></section></main>
<script>
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const duration=n=>{if(n==null)return '—';let s=Math.max(0,Math.floor(n)),d=Math.floor(s/86400);s%=86400;
  let h=Math.floor(s/3600);s%=3600;let m=Math.floor(s/60);return [d&&d+'d',h&&h+'h',(m||(!d&&!h))&&m+'m'].filter(Boolean).join(' ')};
const time=t=>t?new Date(t*1000).toLocaleString():'—';
const number=n=>n==null?'—':Number(n).toLocaleString();
const percent=(n,d)=>d?Math.max(0,Math.min(100,100*n/d)):0;
const phase=(name,done,total)=>{let pct=total?Math.min(100,100*done/total):0;return `<div class="phase"><label><span>${name}</span><b>${done}/${total??'?'}</b></label><div class="bar"><i style="width:${pct}%"></i></div></div>`};
let openRuns=new Set(), logs={};
async function loadLog(id){let r=await fetch('/api/log?run='+id+'&lines=120');let j=await r.json();logs[id]=j.log||j.error||'';render(lastData)}
let lastData={runs:[]},refreshing=false;
function render(data){lastData=data;let states={};for(let r of data.runs)states[r.overall_state]=(states[r.overall_state]||0)+1;
  document.querySelector('#notice').innerHTML='';
  let quotient=data.runs.filter(r=>r.quotient_progress).sort((a,b)=>(b.quotient_progress.wave_target_blocks-a.quotient_progress.wave_target_blocks)||(b.quotient_progress.scanned_blocks-a.quotient_progress.scanned_blocks))[0];
  if(quotient){let q=quotient.quotient_progress,total=q.total_blocks,scanPct=percent(q.scanned_blocks,total),checkPct=percent(q.checkpoint_blocks,total),verifiedPct=percent(q.verified_blocks,total);
    let waveDone=Math.max(0,q.scanned_blocks-q.wave_start_blocks),waveTotal=Math.max(0,q.wave_target_blocks-q.wave_start_blocks),wavePct=percent(waveDone,waveTotal);
    let replayRun=data.runs.filter(r=>r.quotient_progress&&r.quotient_progress.checkpoint_blocks===q.checkpoint_blocks&&(r.quotient_progress.replay.certificate_total||r.quotient_progress.replay.block_total)).sort((a,b)=>b.quotient_progress.latest_scan_at-a.quotient_progress.latest_scan_at)[0];
    let replay=(replayRun?replayRun.quotient_progress.replay:q.replay)||{};
    document.querySelector('#overall').innerHTML=`<section class="overall"><div class="overall-head"><div><h2>Overall 4A bounded-search coverage</h2><div class="muted">${esc(quotient.name)} · layered durable state</div></div><b>${scanPct.toFixed(2)}% scanned</b></div>`+
      `<div class="coverage-label"><span>${number(q.scanned_blocks)} of ${number(total)} nonidentity macroblocks</span><span>${verifiedPct.toFixed(2)}% verified</span></div>`+
      `<div class="coverage"><i class="scanned" style="width:${scanPct}%"></i><i class="checkpoint" style="width:${checkPct}%"></i><i class="verified" style="width:${verifiedPct}%"></i></div>`+
      `<div class="legend"><span><i style="background:#28704e"></i>verified ${number(q.verified_blocks)}</span><span><i style="background:#9b772c"></i>checkpoint ${number(q.checkpoint_blocks)}</span><span><i style="background:#245e92"></i>speculative scan ${number(q.scanned_blocks)}</span></div>`+
      `<div class="wave"><div class="coverage-label"><b>Current wave</b><span>${number(waveDone)} / ${number(waveTotal)} · ${wavePct.toFixed(1)}%</span></div><div class="bar"><i style="width:${wavePct}%"></i></div></div>`+
      `<div class="overall-grid"><div class="overall-stat"><span>scan rate</span><b>${q.rate_blocks_per_second==null?'—':q.rate_blocks_per_second.toFixed(2)+'/s'}</b></div><div class="overall-stat"><span>wave ETA</span><b>${duration(q.eta_seconds)}</b></div><div class="overall-stat"><span>ledger vertices</span><b>${number(q.ledger_vertices)}</b></div><div class="overall-stat"><span>certificate reuse</span><b>${q.reuse_percent==null?'—':q.reuse_percent.toFixed(1)+'%'}</b></div></div>`+
      ((replay.certificate_total||replay.block_total)?`<div class="wave"><div class="coverage-label"><b>Independent replay</b><span>candidate checkpoint</span></div><div class="phase-grid">${phase('certificate segments',replay.certificate_done,replay.certificate_total)}${phase('block segments',replay.block_done,replay.block_total)}</div></div>`:'')+`</section>`;
  }else document.querySelector('#overall').innerHTML='';
  document.querySelector('#summary').innerHTML=`<div class="metric"><span>discovered runs</span><b>${data.runs.length}</b></div>`+
    `<div class="metric"><span>running</span><b>${states.running||0}</b></div><div class="metric"><span>complete</span><b>${states.complete||0}</b></div>`+
    `<div class="metric"><span>failures</span><b>${data.runs.reduce((n,r)=>n+r.failures,0)}</b></div>`;
  document.querySelector('#runs').innerHTML=data.runs.map(r=>{let p=r.progress,e=r.latest_event||{},open=openRuns.has(r.id),expected=p.expected_shards;
    let events=r.recent_events.slice().reverse().map(x=>`<tr><td>${time(x.timestamp)}</td><td>${esc(x.phase)}</td><td>${esc(x.item)}</td><td>${esc(x.state)}</td><td>${esc(x.detail)}</td></tr>`).join('');
    let n=r.native_progress;
    return `<article class="run"><div class="run-head" onclick="toggleRun(${r.id})"><div><h2>${esc(r.name)}</h2><div class="path">${esc(r.path)}</div></div><span class="badge ${r.overall_state}">${esc(r.overall_state)}</span></div>`+
      (open?`<div class="details"><div class="phase-grid">${phase('checkpoints',p.checkpoints,expected)}${phase('representatives',p.representative_verification,expected)}${phase('deep recount',p.deep_recount,expected)}${n?phase('native sampled blocks',n.completed_blocks,n.total_blocks):''}</div>`+
      `<div class="facts"><div>process <b>${esc(r.process.label)}</b></div><div>elapsed <b>${duration(r.elapsed_seconds)}</b></div><div>last activity <b>${duration(r.stale_seconds)} ago</b></div><div>phase <b>${esc(e.phase||'—')} / ${esc(e.state||'—')}</b></div><div>current counters <b>${esc(e.detail||'—')}</b></div>${n?`<div>native ownership <b>${number(n.owned_vertices)} vertices / ${number(n.certificates)} certificates</b></div><div>latest sampled block <b>${number(n.latest_ordinal)} · ${n.latest_block_seconds.toFixed(3)}s</b></div>`:''}<div>certificate <b>${r.artifacts.certificate_complete?'complete':'pending'}</b></div><div>result <b>${r.artifacts.merge_complete?'complete':'pending'}</b></div></div>`+
      `<div><h3>Recent events</h3><table class="events"><thead><tr><th>time</th><th>phase</th><th>item</th><th>state</th><th>detail</th></tr></thead><tbody>${events||'<tr><td colspan="5">No events</td></tr>'}</tbody></table></div>`+
      `<div><button onclick="event.stopPropagation();loadLog(${r.id})">Load log tail</button>${logs[r.id]!=null?`<pre class="log">${esc(logs[r.id])}</pre>`:''}</div></div>`:'')+`</article>`}).join('')||'<div class="muted">No run directories found.</div>';
  document.querySelector('#updated').textContent='updated '+new Date().toLocaleTimeString()+' · polling every 3s';}
function toggleRun(id){openRuns.has(id)?openRuns.delete(id):openRuns.add(id);render(lastData)}
async function refresh(){if(refreshing)return;refreshing=true;try{let r=await fetch('/api/runs',{cache:'no-store'});if(!r.ok)throw Error(r.statusText);render(await r.json())}
  catch(e){document.querySelector('#updated').innerHTML='<span class="error">status request failed</span>';
    document.querySelector('#notice').innerHTML='<p class="error">The dashboard API could not be read: '+esc(e)+'. Check the server terminal and hard-refresh this page.</p>'}
  finally{refreshing=false}}
refresh();setInterval(refresh,3000);
</script></body></html>"""


def discover_runs(roots: list[Path]) -> list[Path]:
    found: set[Path] = set()
    for root in roots:
        root = root.resolve()
        markers = ("progress.tsv", "runner.pid", "result.tsv",
                   "published-result.tsv", "certificate.tsv")
        if any((root / marker).exists() for marker in markers):
            found.add(root)
        if root.exists():
            for marker in markers:
                found.update(path.parent.resolve() for path in root.rglob(marker))
    return sorted(found, key=lambda path: str(path))


def tail_text(path: Path, lines: int) -> str:
    if not path.exists():
        return ""
    with path.open("rb") as handle:
        handle.seek(0, 2)
        position = handle.tell()
        block = 8192
        data = b""
        while position > 0 and data.count(b"\n") <= lines:
            size = min(block, position)
            position -= size
            handle.seek(position)
            data = handle.read(size) + data
    return b"\n".join(data.splitlines()[-lines:]).decode(errors="replace")


class DashboardHandler(BaseHTTPRequestHandler):
    roots: list[Path] = []
    status_cache: list[dict[str, object]] | None = None
    status_cache_at = 0.0
    status_refreshing = False
    status_lock = threading.Lock()
    status_cache_seconds = 10

    @classmethod
    def calculate_statuses(cls, runs: list[Path]) -> list[dict[str, object]]:
        statuses = []
        for index, run in enumerate(runs):
            status = collect_run_status(run, compact_events=True)
            status["id"] = index
            statuses.append(status)
        states = {"running": 0, "paused": 1, "complete": 2, "failed": 3,
                  "stopped": 4, "idle": 5}
        statuses.sort(key=lambda item: (
            states.get(str(item["overall_state"]), 9),
            -(int(item["last_event_at"]) if item["last_event_at"] else 0),
            str(item["path"])))
        return statuses

    @classmethod
    def refresh_statuses(cls, runs: list[Path]) -> None:
        try:
            statuses = cls.calculate_statuses(runs)
            with cls.status_lock:
                cls.status_cache = statuses
                cls.status_cache_at = time.monotonic()
        finally:
            with cls.status_lock:
                cls.status_refreshing = False

    @classmethod
    def cached_statuses(cls, runs: list[Path]) -> list[dict[str, object]]:
        with cls.status_lock:
            cached = cls.status_cache
            stale = time.monotonic() - cls.status_cache_at >= cls.status_cache_seconds
            if cached is not None:
                if stale and not cls.status_refreshing:
                    cls.status_refreshing = True
                    threading.Thread(target=cls.refresh_statuses, args=(runs,),
                                     daemon=True).start()
                return cached
            if not cls.status_refreshing:
                cls.status_refreshing = True
                first = True
            else:
                first = False
        if first:
            cls.refresh_statuses(runs)
        else:
            while True:
                with cls.status_lock:
                    if cls.status_cache is not None:
                        break
                time.sleep(0.05)
        with cls.status_lock:
            return cls.status_cache or []

    def send_bytes(self, content: bytes, content_type: str,
                   status: HTTPStatus = HTTPStatus.OK) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(content)

    def send_json(self, value: object,
                  status: HTTPStatus = HTTPStatus.OK) -> None:
        self.send_bytes(json.dumps(value).encode(), "application/json; charset=utf-8", status)

    def do_HEAD(self) -> None:
        self.do_GET()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        runs = discover_runs(self.roots)
        if parsed.path == "/":
            self.send_bytes(PAGE.encode(), "text/html; charset=utf-8")
        elif parsed.path == "/api/runs":
            self.send_json({"runs": self.cached_statuses(runs)})
        elif parsed.path == "/api/log":
            query = parse_qs(parsed.query)
            try:
                run_id = int(query.get("run", [""])[0])
                lines = min(500, max(1, int(query.get("lines", ["120"])[0])))
                run = runs[run_id]
            except (ValueError, IndexError):
                self.send_json({"error": "invalid run"}, HTTPStatus.BAD_REQUEST)
                return
            self.send_json({"log": tail_text(run / "runner.log", lines)})
        else:
            self.send_json({"error": "not found"}, HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:
        self.send_json({"error": "dashboard is read-only"},
                       HTTPStatus.METHOD_NOT_ALLOWED)

    def log_message(self, format: str, *args: object) -> None:
        sys.stderr.write("dashboard: " + format % args + "\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="local read-only M23 run dashboard")
    parser.add_argument("roots", nargs="*", type=Path, default=[Path("runs")],
                        help="run directories or parent directories (default: runs)")
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", default=8765, type=int)
    args = parser.parse_args()
    DashboardHandler.roots = [root.resolve() for root in args.roots]
    server = ThreadingHTTPServer((args.bind, args.port), DashboardHandler)
    print(f"M23 dashboard: http://{args.bind}:{args.port}")
    print("watching: " + ", ".join(str(root) for root in DashboardHandler.roots))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
