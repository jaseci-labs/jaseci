// run-code.js
import { loadWASM } from 'https://cdn.jsdelivr.net/npm/onigasm@2.2.5/+esm';
import { Registry } from 'https://cdn.jsdelivr.net/npm/monaco-textmate@3.0.1/+esm';
import { wireTmGrammars } from 'https://cdn.jsdelivr.net/npm/monaco-editor-textmate@3.0.0/+esm';

let pyodideWorker = null;
let pyodideReady = false;
let pyodideInitPromise = null;
let monacoLoaded = false;
let monacoLoadPromise = null;
let textmateLoaded = false;
let textmateLoadPromise = null;
const initializedBlocks = new WeakSet();

function initPyodideWorker() {
    if (pyodideWorker) return pyodideInitPromise;
    if (pyodideInitPromise) return pyodideInitPromise;

    pyodideWorker = new Worker("/js/pyodide-worker.js");
    pyodideInitPromise = new Promise((resolve, reject) => {
        pyodideWorker.onmessage = (event) => {
            if (event.data.type === "ready") {
                pyodideReady = true;
                resolve();
            }
        };
        pyodideWorker.onerror = (e) => reject(e);
    });
    pyodideWorker.postMessage({ type: "init" });
    return pyodideInitPromise;
}

function runJacCodeInWorker(code) {
    return new Promise(async (resolve, reject) => {
        await initPyodideWorker();
        const handleMessage = (event) => {
            if (event.data.type === "result") {
                pyodideWorker.removeEventListener("message", handleMessage);
                resolve(event.data.output);
            } else if (event.data.type === "error") {
                pyodideWorker.removeEventListener("message", handleMessage);
                reject(event.data.error);
            }
        };
        pyodideWorker.addEventListener("message", handleMessage);
        pyodideWorker.postMessage({ type: "run", code });
    });
}

async function loadTextMateGrammar() {
    if (textmateLoaded) return textmateLoadPromise;
    if (textmateLoadPromise) return textmateLoadPromise;

    textmateLoadPromise = new Promise(async (resolve, reject) => {
        try {
            await loadMonacoEditor();

            monaco.languages.register({ id: 'jac' });

            const grammarResponse = await fetch("https://raw.githubusercontent.com/jaseci-labs/jaseci/main/jac/support/vscode_ext/jac/syntaxes/jac.tmLanguage.json");
            if (!grammarResponse.ok) throw new Error("Failed to fetch Jac grammar");
            const jacGrammar = await grammarResponse.json();

            const registry = new Registry({
                getGrammarDefinition: async () => ({
                    format: "json",
                    content: jacGrammar,
                }),
            });

            await loadWASM('https://cdn.jsdelivr.net/npm/onigasm@2.2.5/lib/onigasm.wasm');
            console.log("WASM loaded successfully");

            textmateLoaded = true;
            resolve({ registry });

        } catch (err) {
            console.error("Error loading TextMate grammar:", err);
            textmateLoaded = true;
            resolve(null);
        }
    });

    return textmateLoadPromise;
}


function loadMonacoEditor() {
    if (monacoLoaded) return monacoLoadPromise;
    if (monacoLoadPromise) return monacoLoadPromise;

    monacoLoadPromise = new Promise((resolve, reject) => {
        require.config({ paths: { vs: 'https://cdn.jsdelivr.net/npm/monaco-editor@0.52.2/min/vs' } });
        require(['vs/editor/editor.main'], function () {
            monaco.editor.defineTheme("jac-theme", {
                base: "vs-dark",
                inherit: true,
                rules: [
                    { token: "storage.type.class.jac", foreground: "569CD6" },
                    { token: "storage.type.function.jac", foreground: "569CD6" },
                    { token: "keyword.control.flow.jac", foreground: "C678DD" },
                    { token: "entity.name.type.class.jac", foreground: "3ac9b0" },
                ],
                colors: {
                    "editor.foreground": "#D4D4D4",
                }
            });
            monaco.editor.setTheme("jac-theme");
            monacoLoaded = true;
            resolve();
        }, reject);
    });
    console.log("Loading Monaco Editor...");
    return monacoLoadPromise;
}

async function setupCodeBlock(div) {
    if (div._monacoInitialized) return;

    div._monacoInitialized = true;
    const originalCode = div.textContent.trim();

    div.innerHTML = `
            <div class="jac-code-loading" style="padding: 10px; font-style: italic; color: gray;">
                Loading editor...
            </div>
        `;

    try {
        await loadTextMateGrammar();
        const { registry } = await loadTextMateGrammar();

        div.innerHTML = `
            <div class="jac-code" style="border: 1px solid #ccc;"></div>
            <button class="md-button md-button--primary run-code-btn">Run</button>
            <pre class="code-output" style="display:none; white-space: pre-wrap; background: #1e1e1e; color: #d4d4d4; padding: 10px;"></pre>
            `;

        const container = div.querySelector(".jac-code");
        const runButton = div.querySelector(".run-code-btn");
        const outputBlock = div.querySelector(".code-output");

        const uri = monaco.Uri.parse(`inmemory://model.jac`);
        const model = monaco.editor.createModel(originalCode || '# Write your Jac code here', "jac", uri);

        const editor = monaco.editor.create(container, {
            model: model,
            theme: 'jac-theme',
            language: 'jac',
            scrollBeyondLastLine: false,
            scrollbar: {
                vertical: 'hidden',
                handleMouseWheel: false,
            },
            minimap: {
                enabled: false
            },
            automaticLayout: true,
            padding: {
                top: 10,
                bottom: 10
            },
            tabSize: 4,
            autoIndent: 'advanced',
            formatOnPaste: true,
            formatOnType: true
        });

        const grammars = new Map();
        grammars.set('jac', 'source.jac');

        await wireTmGrammars(monaco, registry, grammars);

        function updateEditorHeight() {
            const lineCount = editor.getModel().getLineCount();
            const lineHeight = editor.getOption(monaco.editor.EditorOption.lineHeight);
            const height = lineCount * lineHeight + 20;
            container.style.height = `${height}px`;
            editor.layout();
        }
        updateEditorHeight();
        editor.onDidChangeModelContent(updateEditorHeight);

        runButton.addEventListener("click", async () => {
            outputBlock.style.display = "block";

            if (!pyodideReady) {
                outputBlock.textContent = "Loading Jac runner...";
                await initPyodideWorker();
            }

            outputBlock.textContent = "Running...";
            try {
                const codeToRun = editor.getValue();
                const result = await runJacCodeInWorker(codeToRun);
                outputBlock.textContent = `Output:\n${result}`;
            } catch (error) {
                outputBlock.textContent = `Error:\n${error}`;
            }
        });
    } catch (error) {
        console.error("Error setting up code block:", error);
        div.innerHTML = `
                <div class="jac-code-error" style="padding: 10px; color: red;">
                    Error loading editor. Please refresh the page.
                </div>
                <pre>${originalCode}</pre>
            `;
    }
}

const lazyObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const div = entry.target;
            if (!initializedBlocks.has(div)) {
                setupCodeBlock(div);
                initializedBlocks.add(div);
                lazyObserver.unobserve(div);
            }
        }
    });
}, {
    root: null,
    rootMargin: "0px",
    threshold: 0.1
});

function observeUninitializedCodeBlocks() {
    document.querySelectorAll('.code-block').forEach((block) => {
        if (!initializedBlocks.has(block)) {
            lazyObserver.observe(block);
        }
    });
}

const domObserver = new MutationObserver(() => {
    observeUninitializedCodeBlocks();
});

function initializeCodeBlocks() {
    observeUninitializedCodeBlocks();
    initPyodideWorker();
}

domObserver.observe(document.body, {
    childList: true,
    subtree: true
});

if (document.readyState === 'loading') {
    document.addEventListener("DOMContentLoaded", initializeCodeBlocks);
} else {
    initializeCodeBlocks();
}

initializeCodeBlocks();
