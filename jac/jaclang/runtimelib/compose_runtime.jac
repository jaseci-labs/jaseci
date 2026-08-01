obj Composable {}

obj Dp {
    has value: float = 0.0;
}

obj ModifierChain {
    def fillMaxSize(fraction: float = 1.0) -> ModifierChain;
    def fillMaxWidth(fraction: float = 1.0) -> ModifierChain;
    def fillMaxHeight(fraction: float = 1.0) -> ModifierChain;
    def wrapContentSize(align: (str | None) = None) -> ModifierChain;
    def width(w: Dp) -> ModifierChain;
    def height(h: Dp) -> ModifierChain;
    def size(s: Dp) -> ModifierChain;
    def padding(
        all: (Dp | None) = None,
        horizontal: (Dp | None) = None,
        vertical: (Dp | None) = None,
        start: (Dp | None) = None,
        top: (Dp | None) = None,
        end: (Dp | None) = None,
        bottom: (Dp | None) = None
    ) -> ModifierChain;

    def clip(shape: (str | None) = None) -> ModifierChain;
    def background(color: (str | None) = None) -> ModifierChain;
    def border(width: Dp, color: (str | None) = None) -> ModifierChain;
    def clickable(enabled: bool = True, onClick: (any | None) = None) -> ModifierChain;
}

glob Modifier: ModifierChain = ModifierChain();

obj TypographyStyles {
    has displayLarge: any = None,
        displayMedium: any = None,
        displaySmall: any = None,
        headlineLarge: any = None,
        headlineMedium: any = None,
        headlineSmall: any = None,
        titleLarge: any = None,
        titleMedium: any = None,
        titleSmall: any = None,
        bodyLarge: any = None,
        bodyMedium: any = None,
        bodySmall: any = None,
        labelLarge: any = None,
        labelMedium: any = None,
        labelSmall: any = None;
}

glob Typography: TypographyStyles = TypographyStyles(),
     Arrangement: any,
     Alignment: any,
     MaterialTheme: any,
     Icons: any;

def:pub Column(
    modifier: (ModifierChain | None) = None,
    verticalArrangement: any = None,
    horizontalAlignment: any = None
) -> Composable;

def:pub Row(
    modifier: (ModifierChain | None) = None,
    horizontalArrangement: any = None,
    verticalAlignment: any = None
) -> Composable;

def:pub Box(
    modifier: (ModifierChain | None) = None, contentAlignment: any = None
) -> Composable;

def:pub Scaffold(
    modifier: (ModifierChain | None) = None, topBar: any = None, bottomBar: any = None
) -> Composable;

def:pub LazyColumn(modifier: (ModifierChain | None) = None) -> Composable;

def:pub LazyRow(modifier: (ModifierChain | None) = None) -> Composable;

def:pub Spacer(modifier: (ModifierChain | None) = None) -> Composable;

def:pub Surface(
    modifier: (ModifierChain | None) = None, color: any = None
) -> Composable;

def:pub Text(text: any = "", style: any = None, color: any = None) -> Composable;

def:pub Icon(
    imageVector: any = None,
    contentDescription: any = None,
    modifier: (ModifierChain | None) = None,
    tint: any = None
) -> Composable;

def:pub Image(
    painter: any = None,
    contentDescription: any = None,
    modifier: (ModifierChain | None) = None
) -> Composable;

def:pub Button(
    onClick: any = None, modifier: (ModifierChain | None) = None, enabled: bool = True
) -> Composable;

def:pub FloatingActionButton(
    onClick: any = None, modifier: (ModifierChain | None) = None
) -> Composable;

def:pub OutlinedTextField(
    value: any = "",
    onValueChange: any = None,
    modifier: (ModifierChain | None) = None,
    placeholder: any = None,
    label: any = None
) -> Composable;

def:pub TextField(
    value: any = "",
    onValueChange: any = None,
    modifier: (ModifierChain | None) = None,
    placeholder: any = None,
    label: any = None
) -> Composable;

def:pub Card(modifier: (ModifierChain | None) = None) -> Composable;

def:pub TopAppBar(
    title: any = None, modifier: (ModifierChain | None) = None
) -> Composable;

def:pub Checkbox(
    checked: bool = False,
    onCheckedChange: any = None,
    modifier: (ModifierChain | None) = None
) -> Composable;

def:pub Switch(
    checked: bool = False,
    onCheckedChange: any = None,
    modifier: (ModifierChain | None) = None
) -> Composable;

def:pub HorizontalDivider(modifier: (ModifierChain | None) = None) -> Composable;

def:pub CircularProgressIndicator(
    modifier: (ModifierChain | None) = None
) -> Composable;

def:pub Raw(kotlin: str = "") -> Composable;
