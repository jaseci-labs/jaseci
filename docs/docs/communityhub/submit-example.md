# 🧑‍💻 Submit a Jac Example

<style>
    body { font-family: sans-serif; padding: 20px; }
    input, textarea, select { width: 100%; padding: 6px; margin: 5px 0; }
    #editor { height: 300px; border: 1px solid #ccc; margin-top: 10px; }
    button { margin-top: 10px; padding: 8px 16px; }
    #new-folder-group { display: none; }
</style>

<div>
    <form id="example-form">
        <label>📁 Folder:</label>
        <select id="folder-select" name="folder-select" required>
            <option value="" disabled selected>Select a folder</option>
        </select>
        <div id="new-folder-group">
            <label>New Folder Name:</label>
            <input type="text" id="new-folder" name="new-folder" placeholder="Enter new folder name" />
        </div>

        <label>📄 File Name (without .jac):</label>
        <input type="text" id="filename" name="filename" required />

        <label>✍️ Jac Code:</label>
        <div id="editor"></div>

        <button type="button" onclick="downloadExample()">📥 Download Files</button>
    </form>
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs/loader.min.js"></script>
<script>
    let editor;
    let folders = [];

    require.config({ paths: { 'vs': 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs' } });
    require(['vs/editor/editor.main'], function () {
      editor = monaco.editor.create(document.getElementById('editor'), {
        value: "// Write your Jac code here...",
        language: 'python', // close to Jac syntax
        theme: 'vs-dark'
      });

      // Load saved draft
      const saved = JSON.parse(localStorage.getItem("jac_example_draft") || "{}");
      if (saved.code) editor.setValue(saved.code);
      ['folder', 'title', 'filename', 'description', 'tags'].forEach(id => {
        if (saved[id]) {
            const el = document.getElementById(id);
            if (el) el.value = saved[id];
        }
      });

      // Auto-save
      setInterval(() => {
        const draft = {
          code: editor.getValue(),
          folder: getSelectedFolder(),
          title: document.getElementById('title') ? document.getElementById('title').value : "",
          filename: filename.value,
          description: document.getElementById('description') ? document.getElementById('description').value : "",
          tags: document.getElementById('tags') ? document.getElementById('tags').value : ""
        };
        localStorage.setItem("jac_example_draft", JSON.stringify(draft));
      }, 1000);
    });

    function getSelectedFolder() {
      const select = document.getElementById('folder-select');
      if (select.value === '__new__') {
        return document.getElementById('new-folder').value.trim();
      }
      return select.value;
    }

    function downloadExample() {
      const code = editor.getValue();
      const folder = getSelectedFolder();
      const title = document.getElementById('title') ? document.getElementById('title').value.trim() : "";
      const filename = document.getElementById("filename").value.trim();
      const description = document.getElementById('description') ? document.getElementById('description').value.trim() : "";
      const tags = document.getElementById('tags') ? document.getElementById('tags').value.trim().split(',').map(t => t.trim()) : [];

      const path = `${folder}/${filename}.jac`;
      const meta = {
        title,
        description,
        tags,
        category: folder,
        path: `${folder}/`
      };

      const codeBlob = new Blob([code], { type: "text/plain" });
      const metaBlob = new Blob([JSON.stringify(meta, null, 2)], { type: "application/json" });

      const codeUrl = URL.createObjectURL(codeBlob);
      const metaUrl = URL.createObjectURL(metaBlob);

      const download = (url, name) => {
        const a = document.createElement("a");
        a.href = url;
        a.download = name;
        a.click();
        URL.revokeObjectURL(url);
      };

      download(codeUrl, `${filename}.jac`);
      download(metaUrl, `${filename}.meta.json`);
    }

    // Fetch and show available folders/files from jac_examples.json
    fetch('/assets/jac_examples.json')
    .then(r => r.json())
    .then(data => {
        const ul = document.getElementById('jac-folders-list');
        folders = Object.keys(data);
        // Populate folder dropdown
        const select = document.getElementById('folder-select');
        folders.forEach(folder => {
            const opt = document.createElement('option');
            opt.value = folder;
            opt.textContent = folder;
            select.appendChild(opt);
        });
        // Add "New Folder..." option
        const newOpt = document.createElement('option');
        newOpt.value = '__new__';
        newOpt.textContent = '➕ New Folder...';
        select.appendChild(newOpt);

        // Show folders/files list
        Object.entries(data).forEach(([folder, files]) => {
            const li = document.createElement('li');
            li.innerHTML = `<strong>${folder}</strong><ul style="margin:0 0 8px 16px; padding:0;">${
                Object.entries(files).map(([name, path]) =>
                `<li style="font-size: 0.97em;">${name} <span style="color:#aaa;">(${path})</span></li>`
                ).join('')
            }</ul>`;
            ul.appendChild(li);
        });
    });

    // Show/hide new folder input based on dropdown
    document.addEventListener('DOMContentLoaded', function () {
        const select = document.getElementById('folder-select');
        const newFolderGroup = document.getElementById('new-folder-group');
        select.addEventListener('change', function () {
            if (select.value === '__new__') {
                newFolderGroup.style.display = 'block';
                document.getElementById('new-folder').required = true;
            } else {
                newFolderGroup.style.display = 'none';
                document.getElementById('new-folder').required = false;
            }
        });
    });
</script>