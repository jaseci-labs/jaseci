document.addEventListener('DOMContentLoaded', function() {
    if (typeof mermaid !== 'undefined') {
        mermaid.initialize({
            startOnLoad: true,
            theme: 'dark',
            themeVariables: {
                darkMode: true,
                primaryColor: '#ff6b35',
                primaryTextColor: '#ffffff',
                primaryBorderColor: '#ff6b35',
                lineColor: '#ffffff',
                secondaryColor: '#1e1e1e',
                tertiaryColor: '#2d2d2d'
            },
            securityLevel: 'loose',
            fontFamily: 'Roboto, sans-serif',
            logLevel: 'error'
        });

        // Re-render Mermaid diagrams when navigating (for MkDocs Material instant loading)
        if (typeof app !== 'undefined') {
            app.document$.subscribe(() => {
                mermaid.init();
            });
        }
    }
});

// Fallback initialization for cases where DOMContentLoaded has already fired
if (document.readyState === 'loading') {
    // Document is still loading, DOMContentLoaded will fire
} else {
    // Document has already loaded
    if (typeof mermaid !== 'undefined') {
        mermaid.initialize({
            startOnLoad: true,
            theme: 'dark',
            themeVariables: {
                darkMode: true,
                primaryColor: '#ff6b35',
                primaryTextColor: '#ffffff',
                primaryBorderColor: '#ff6b35',
                lineColor: '#ffffff',
                secondaryColor: '#1e1e1e',
                tertiaryColor: '#2d2d2d'
            },
            securityLevel: 'loose',
            fontFamily: 'Roboto, sans-serif',
            logLevel: 'error'
        });
    }
}