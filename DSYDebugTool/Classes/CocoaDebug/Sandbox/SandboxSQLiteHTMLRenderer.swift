import Foundation

enum SandboxSQLiteHTMLRenderer {
    static func escapeHTML(_ value: String) -> String {
        var escaped = value
        escaped = escaped.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&#039;")
        return escaped
    }

    static func localTablePage(
        tableName: String,
        totalRows: Int,
        page: Int,
        pageSize: Int,
        rows: SandboxSQLiteRows
    ) -> String {
        let safePageSize = max(pageSize, 1)
        let start = totalRows == 0 ? 0 : page * safePageSize + 1
        let end = min((page + 1) * safePageSize, totalRows)
        let headerHTML = rows.columns.map { "<th>\(escapeHTML($0))</th>" }.joined()
        let bodyHTML: String

        if rows.rows.isEmpty {
            bodyHTML = "<tr><td class=\"empty\" colspan=\"\(max(rows.columns.count, 1))\">No rows</td></tr>"
        } else {
            bodyHTML = rows.rows.enumerated().map { rowIndex, row in
                let rowID = rows.rowIDs.indices.contains(rowIndex) ? rows.rowIDs[rowIndex] : nil
                let rowJSON = rowJSONString(columns: rows.columns, row: row)
                let cells = rows.columns.enumerated().map { columnIndex, column in
                    let value = row[column] ?? ""
                    let isCopyColumn = columnIndex == 0
                    let editable = rowID != nil && !isCopyColumn
                    let rowIDAttribute = rowID.map { "\($0)" } ?? ""
                    let copyClass = isCopyColumn ? " copy-row" : ""
                    let copyAttribute = isCopyColumn ? " data-row=\"\(escapeHTML(rowJSON))\" title=\"长按复制当前行\"" : ""
                    return """
                    <td class="\(editable ? "editable" : "readonly")\(copyClass)" data-editable="\(editable ? "1" : "0")" data-rowid="\(escapeHTML(rowIDAttribute))" data-column="\(escapeHTML(column))" data-value="\(escapeHTML(value))"\(copyAttribute)>\(escapeHTML(value))</td>
                    """
                }.joined()
                return "<tr>\(cells)</tr>"
            }.joined()
        }

        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>
        \(sharedCSS)
        body{margin:0;background:#f6f8fa}
        .page{padding:12px}
        .title{font-weight:700;margin-bottom:4px}
        .meta{color:#667085;margin-bottom:10px;font-size:13px}
        .hint{color:#0f7b4f;margin-bottom:10px;font-size:13px}
        .empty{text-align:center;color:#667085}
        td.editable{cursor:pointer}
        td.editable:active{background:#eaf5ef}
        td.copy-row{font-weight:600;text-decoration:underline;text-decoration-style:dotted;text-underline-offset:3px}
        </style>
        </head>
        <body>
        <div class="page">
          <div class="title">\(escapeHTML(tableName))</div>
          <div class="meta">Rows \(start)-\(end) of \(totalRows)</div>
          <div class="hint">长按首列复制当前行，长按其他单元格可修改</div>
          <div class="table-wrap">
            <table>
              <thead><tr>\(headerHTML)</tr></thead>
              <tbody>\(bodyHTML)</tbody>
            </table>
          </div>
        </div>
        <script>
        let pressTimer=null;
        let copyPressTimer=null;
        function clearPress(){if(pressTimer){clearTimeout(pressTimer);pressTimer=null}}
        function clearCopyPress(){if(copyPressTimer){clearTimeout(copyPressTimer);copyPressTimer=null}}
        document.querySelectorAll('td.editable').forEach(function(cell){
          cell.addEventListener('touchstart',function(){
            clearPress();
            pressTimer=setTimeout(function(){postEdit(cell)},650);
          },{passive:true});
          cell.addEventListener('touchend',clearPress,{passive:true});
          cell.addEventListener('touchmove',clearPress,{passive:true});
          cell.addEventListener('mousedown',function(){
            clearPress();
            pressTimer=setTimeout(function(){postEdit(cell)},650);
          });
          cell.addEventListener('mouseup',clearPress);
          cell.addEventListener('mouseleave',clearPress);
        });
        document.querySelectorAll('td.copy-row').forEach(function(cell){
          cell.addEventListener('touchstart',function(){
            clearCopyPress();
            copyPressTimer=setTimeout(function(){postCopyRow(cell)},650);
          },{passive:true});
          cell.addEventListener('touchend',clearCopyPress,{passive:true});
          cell.addEventListener('touchmove',clearCopyPress,{passive:true});
          cell.addEventListener('mousedown',function(){
            clearCopyPress();
            copyPressTimer=setTimeout(function(){postCopyRow(cell)},650);
          });
          cell.addEventListener('mouseup',clearCopyPress);
          cell.addEventListener('mouseleave',clearCopyPress);
        });
        function postCopyRow(cell){
          clearCopyPress();
          if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.sqliteCopyRow){
            window.webkit.messageHandlers.sqliteCopyRow.postMessage({row: cell.dataset.row});
          }
        }
        function postEdit(cell){
          clearPress();
          if(cell.dataset.editable!=='1'){return}
          if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.sqliteEdit){
            window.webkit.messageHandlers.sqliteEdit.postMessage({
              rowID: cell.dataset.rowid,
              column: cell.dataset.column,
              value: cell.dataset.value
            });
          }
        }
        </script>
        </body>
        </html>
        """
    }

    static func webBrowserPage() -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>SQLite Browser</title>
        <style>
        \(sharedCSS)
        body{margin:0;background:#f6f8fa}
        header{background:#111827;color:white;padding:14px 18px;font-weight:700}
        main{display:grid;grid-template-columns:240px 1fr;min-height:calc(100vh - 50px)}
        aside{background:white;border-right:1px solid #d8dee4;padding:12px;overflow:auto}
        button{border:0;background:white;padding:10px;border-radius:6px;cursor:pointer}
        aside button{display:block;width:100%;text-align:left}
        button:hover,button.active{background:#eaf5ef;color:#0f7b4f}
        section{padding:16px;overflow:auto}
        .bar{display:flex;gap:8px;align-items:center;margin-bottom:12px;flex-wrap:wrap}
        .search{display:flex;gap:8px;align-items:center;margin-bottom:12px;max-width:560px}
        .search input{flex:1;border:1px solid #c9d1d9;border-radius:6px;padding:9px 10px;font-size:14px}
        .search button,.pager{width:auto;border:1px solid #c9d1d9;background:white;text-align:center}
        .pager{width:auto;border:1px solid #c9d1d9;background:white;text-align:center}
        td.editable{cursor:pointer}
          td.editable:hover{background:#f4fbf7}
        td.copy-row{font-weight:600;text-decoration:underline;text-decoration-style:dotted;text-underline-offset:3px}
        .notice{position:fixed;left:50%;top:44px;transform:translateX(-50%);background:rgba(17,24,39,.9);color:white;border-radius:8px;padding:9px 16px;font-size:14px;opacity:0;pointer-events:none;transition:opacity .18s}
        .notice.show{opacity:1}
        .muted{color:#667085}
        @media(max-width:760px){main{grid-template-columns:1fr}aside{border-right:0;border-bottom:1px solid #d8dee4}}
        </style>
        </head>
        <body>
        <header>SQLite Browser</header>
        <main><aside id="tables"></aside><section id="content" class="muted">Loading...</section></main>
        <script>
        let pageSize=100;
        let longPressMs=650;
        let state={table:null,page:0,keyword:''};
        let timers=new WeakMap();
        async function getJSON(url){const r=await fetch(url);const j=await r.json();if(!r.ok||j.error)throw new Error(j.error||r.statusText);return j}
        async function loadTables(){try{const data=await getJSON('/api/tables');const box=document.getElementById('tables');box.innerHTML='';if(!data.tables.length){box.textContent='No tables';return}data.tables.forEach(t=>{const b=document.createElement('button');b.textContent=t;b.onclick=()=>selectTable(t,b);box.appendChild(b)});selectTable(data.tables[0],box.querySelector('button'))}catch(e){showError(e)}}
        async function selectTable(table,button){state.table=table;state.page=0;state.keyword='';document.querySelectorAll('aside button').forEach(b=>b.classList.remove('active'));if(button)button.classList.add('active');await loadRows()}
        async function loadRows(){try{const url='/api/rows?table='+encodeURIComponent(state.table)+'&page='+state.page+'&pageSize='+pageSize+'&q='+encodeURIComponent(state.keyword);const data=await getJSON(url);renderRows(data)}catch(e){showError(e)}}
        function renderRows(data){
          const totalPages=Math.max(1,Math.ceil(data.total/data.pageSize));
          const searchValue=escapeHTML(state.keyword);
          let html='<div class="bar"><strong>'+escapeHTML(data.table)+'</strong><span class="muted">'+data.total+' rows</span><button class="pager" onclick="state.page=Math.max(0,state.page-1);loadRows()">Prev</button><span>Page '+(state.page+1)+' / '+totalPages+'</span><button class="pager" onclick="state.page=Math.min('+ (totalPages-1) +',state.page+1);loadRows()">Next</button></div>';
          html+='<div class="search"><input id="search" value="'+searchValue+'" placeholder="Search current table"><button onclick="applySearch()">Search</button><button onclick="clearSearch()">Clear</button></div>';
          html+='<div class="muted" style="margin-bottom:10px">长按首列复制当前行，双击或长按其他单元格可修改，输入 NULL 将写入数据库 NULL。</div>';
          html+='<div id="notice" class="notice"></div>';
          html+='<div class="table-wrap"><table><thead><tr>'+data.columns.map(c=>'<th>'+escapeHTML(c)+'</th>').join('')+'</tr></thead><tbody>';
          data.rows.forEach((row,index)=>{
            const rowID=(data.rowIDs||[])[index];
            html+='<tr>'+data.columns.map(c=>{
              const value=row[c]??'';
              const editable=rowID!==null&&rowID!==undefined;
              const copyable=c===data.columns[0];
              const rowData=copyable?' data-row="'+escapeHTML(JSON.stringify(row,null,2))+'" title="Long press to copy this row"':'';
              const canEdit=editable&&!copyable;
              return '<td class="'+(canEdit?'editable':'readonly')+(copyable?' copy-row':'')+'" data-editable="'+(canEdit?'1':'0')+'" data-rowid="'+escapeHTML(rowID??'')+'" data-column="'+escapeHTML(c)+'" data-value="'+escapeHTML(value)+'"'+rowData+'>'+escapeHTML(value)+'</td>';
            }).join('')+'</tr>';
          });
          html+='</tbody></table></div>';
          document.getElementById('content').innerHTML=html;
          const input=document.getElementById('search');
          input.addEventListener('keydown',e=>{if(e.key==='Enter')applySearch()});
          bindEditableCells();
          bindCopyCells();
        }
        function applySearch(){state.keyword=document.getElementById('search').value.trim();state.page=0;loadRows()}
        function clearSearch(){state.keyword='';state.page=0;loadRows()}
        function bindEditableCells(){document.querySelectorAll('td.editable').forEach(cell=>{
          cell.addEventListener('dblclick',()=>editCell(cell));
          cell.addEventListener('touchstart',()=>startPress(cell),{passive:true});
          cell.addEventListener('touchend',()=>clearPress(cell),{passive:true});
          cell.addEventListener('touchmove',()=>clearPress(cell),{passive:true});
          cell.addEventListener('mousedown',()=>startPress(cell));
          cell.addEventListener('mouseup',()=>clearPress(cell));
          cell.addEventListener('mouseleave',()=>clearPress(cell));
        })}
        function bindCopyCells(){document.querySelectorAll('td.copy-row').forEach(cell=>{
          cell.addEventListener('touchstart',()=>startCopyPress(cell),{passive:true});
          cell.addEventListener('touchend',()=>clearPress(cell),{passive:true});
          cell.addEventListener('touchmove',()=>clearPress(cell),{passive:true});
          cell.addEventListener('mousedown',()=>startCopyPress(cell));
          cell.addEventListener('mouseup',()=>clearPress(cell));
          cell.addEventListener('mouseleave',()=>clearPress(cell));
        })}
        function startCopyPress(cell){clearPress(cell);timers.set(cell,setTimeout(()=>copyRow(cell.dataset.row),longPressMs))}
        async function copyRow(text){
          try{
            if(navigator.clipboard&&window.isSecureContext){await navigator.clipboard.writeText(text)}
            else{fallbackCopy(text)}
            showNotice('已复制当前行数据');
          }catch(e){fallbackCopy(text)}
        }
        function fallbackCopy(text){
          const area=document.createElement('textarea');
          area.value=text;
          area.style.position='fixed';
          area.style.left='-9999px';
          document.body.appendChild(area);
          area.focus();
          area.select();
          document.execCommand('copy');
          document.body.removeChild(area);
        }
        function showNotice(text){
          const notice=document.getElementById('notice');
          if(!notice)return;
          notice.textContent=text;
          notice.classList.add('show');
          setTimeout(()=>notice.classList.remove('show'),1200);
        }
        function startPress(cell){clearPress(cell);timers.set(cell,setTimeout(()=>editCell(cell),longPressMs))}
        function clearPress(cell){const timer=timers.get(cell);if(timer){clearTimeout(timer);timers.delete(cell)}}
        async function editCell(cell){
          clearPress(cell);
          if(cell.dataset.editable!=='1')return;
          const current=cell.dataset.value==='NULL'?'':cell.dataset.value;
          const next=prompt('修改 '+cell.dataset.column+'；输入 NULL 将写入数据库 NULL',current);
          if(next===null)return;
          const isNull=next.trim().toUpperCase()==='NULL';
          try{
            const r=await fetch('/api/update',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({table:state.table,column:cell.dataset.column,rowID:Number(cell.dataset.rowid),value:next,isNull:isNull})});
            const j=await r.json();
            if(!r.ok||j.error)throw new Error(j.error||r.statusText);
            await loadRows();
          }catch(e){showError(e)}
        }
        function showError(e){document.getElementById('content').textContent=e.message}
        function escapeHTML(v){return String(v).replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[m]))}
        loadTables();
        </script>
        </body>
        </html>
        """
    }

    private static var sharedCSS: String {
        """
        *{box-sizing:border-box}
        body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;color:#1f2933}
        .table-wrap{overflow:auto;border:1px solid #d8dee4;background:white;max-width:100%;max-height:calc(100vh - 92px)}
        table{border-collapse:collapse;width:max-content;min-width:100%}
        th,td{border:1px solid #d8dee4;padding:8px 10px;vertical-align:top;white-space:pre-wrap;min-width:120px;max-width:320px;font-size:13px;line-height:1.35}
        th{background:#f0f3f6;text-align:left;position:sticky;top:0;z-index:1}
        """
    }

    private static func rowJSONString(columns: [String], row: [String: String]) -> String {
        let orderedRow = columns.reduce(into: [String: String]()) { result, column in
            result[column] = row[column] ?? ""
        }
        guard let data = try? JSONSerialization.data(withJSONObject: orderedRow, options: [.prettyPrinted]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
