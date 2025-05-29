# Jaclang Package & Import System

Jaclang features a modular package system that helps organize code across multiple files and folders, enhancing reusability, clean design, and scalability. Similar to Python, Jac packages are directories containing an `__init__.jac` file that defines what is exposed when the package is imported. This structure allows developers to group related code logically and control the public interface of the package, making it easier to manage larger projects efficiently.

## Folder structure

```mermaid
flowchart TD
    A["Project"] --> B["main.jac"] & C["library"]
    C --> D["__init__.jac"] & E["tools.jac"] & F["sub"]
    F --> G["__init__.jac"] & H["helper.jac"]
    style A stroke:#FF6D00
    style B stroke:#FF6D00
    style C stroke:#FF6D00
    style D stroke:#FF6D00
    style E stroke:#FF6D00
    style F stroke:#FF6D00
    style G stroke:#FF6D00
    style H stroke:#FF6D00
    linkStyle 2 stroke:#FFFFFF,fill:none
```

## File Description

1.Main.jac file

- This is the **entry point** to the project.

```Jac linenums="1"
import from library { tool_func }
import from library.sub { help_func }

with entry {
    print('Main Execution:\n') ;
    print('Calling from tools.jac...') ;
    print('Tool says:', tool_func()) ;
    print('\nCalling from helper.jac...') ;
    print('Helper says:', help_func()) ;
}
```

2.library/__init_.jac

This file initializes the `library` package, exposing the `tool_func` function.

```Jac linenums="1"
import from .tools { tool_func }
```

3.library/tools.jac

A utility function implementation.

```Jac linenums="1"
def tool_func() {
    return 'Tool function executed';
}
```

4.library/sub/__init_.jac

Used to expose functionality from the sub-package. Defines or re-exports `help_func`.

```Jac linenums="1"
import from .helper { help_func }
```

5.library/sub/helper.jac

Alternatively, we can define `help_func` in `helper.jac` and import it into the `__init__.jac`. Here, `..` refers to the parent directory, allowing relative imports within the Jac project structure.

```Jac linenums="1"
import from ..tools { tool_func }

def help_func() {
    return 'Helper function called' ;
}

with entry {
    print('Tool says:', tool_func()) ;
}
```

## How Cross-Module Access works in Jaclang

Jaclang allows importing functions, variables, or objects from other modules using `absolute` or `relative` import paths.

1.Absolute Imports

```Jac linenums="1"
#main.jac
import from library.tools { tool_func }
import from library.sub.helper { help_func }
```

Absolute imports specify the complete path to a module starting from the root of the project. They are useful for clearly indicating where a module is located within the overall folder structure and remain consistent regardless of the location of the importing file.

2.Relative Imports

Relative imports use dots `(. or ..)` to indicate location relative to the current file.

- **Single dot (.)** - Current directory/module

```Jac linenums="1"
#library/sub/__init__.jac
import from .helper { help_func }
```

The dot `.` in Jac imports means **current directory**. It lets you import modules or functions from the same folder as the current file, making code easier to organize and maintain without needing full paths. This is useful for accessing sibling files within a package cleanly and flexibly.

- **Double dot (..)** - parent directory

```Jac linenums="1"
#library/sub/helper.jac
import from ..tools { tool_func }
```
The `..` in Jac imports lets you access modules in the parent directory relative to the current file. It makes imports flexible and easier to manage by avoiding full absolute paths, helping keep code organized and maintainable in complex projects.

## How `__init__.jac` works in Jaclang

In Jaclang, the `__init__.jac` file plays a crucial role by defining the public interface of a package. It determines which parts of the package are exposed and accessible when the package is imported, helping manage and organize code effectively within modular structures.

1.Marks a Directory as a Jac Package

The `__init__.jac` file marks a directory as a Jac package and defines what is exposed when importing it. When Jaclang finds a folder with an `__init__.jac` file, it treats that folder as a package, allowing it to be used for imports rather than just a regular directory. Without this file, Jac won’t recognize the folder as a package properly, which can cause import issues and limit modular code organization.

```mermaid
flowchart TD
    A["library"] --> B["__init__.jac"]
    A --> C["tools.jac"]

    %% Comment nodes
    Bc["Makes 'library' an importable Jac package"]

    %% Link comments to files
    B --- Bc

    %% Styling
    style A stroke:#FF6D00
    style B stroke:#FF6D00
    style C stroke:#FF6D00

    style Bc fill:none,stroke:#FFFFFF,stroke-width:1px,font-style:italic,font-size:12px

    linkStyle default stroke:#FFFFFF,fill:none
```

2.Allows Selective Exports of functionality

The `__init__.jac` file can **import specific functions, classes, or modules** from within the package and make them available for use when the package is imported.

```Jac linenums="1"
import from .tools { tool_func } # expose tool_func
```

In this abstraction helps to:

- Hide internal logic
- Make refactoring easier.

3.Enables Grouping and Organizing of Modules

We can structure projects into meaningful subdirectories and use `__init__.jac` files at different levels to expose only the necessary components.

```mermaid
flowchart TD
    A["library"] --> B["__init__.jac"]
    A --> C["tools.jac"]
    A --> D["sub"]
    D --> E["__init__.jac"]
    D --> F["helper.jac"]

    %% Comment nodes
    Bc["Can import from tools.jac and sub/__init__.jac"]
    Ec["Can import from helper.jac"]

    %% Link comments to files
    B --- Bc
    E --- Ec

    %% Styling
    style A stroke:#FF6D00
    style B stroke:#FF6D00
    style C stroke:#FF6D00
    style D stroke:#FF6D00
    style E stroke:#FF6D00
    style F stroke:#FF6D00

    style Bc fill:none,stroke:#FFFFFF,stroke-width:1px,font-style:italic,font-size:12px
    style Ec fill:none,stroke:#FFFFFF,stroke-width:1px,font-style:italic,font-size:12px

    linkStyle default stroke:#FFFFFF,fill:none
```

4. Makes Submodules Accessible During Imports

The __init__.jac file allows **exposing submodules** so that nested components can be accessed through **top-level imports**. This simplifies import statements in other files.

`library/__init__.jac`
```Jac linenums="1"
import from .tools { tool_func }
```

By including this import, you can now write the following in `main.jac`

```Jac linenums="1"
import from library { tool_func, help_func }

with entry {
    print('Main Execution:\n') ;
    print('Calling from tools.jac...') ;
    print('Tool says:', tool_func()) ;
    print('\nCalling from helper.jac...') ;
    print('Helper says:', help_func()) ;
}
```

Without the import in `library/__init__.jac`, you would need more explicit, nested imports:

```Jac linenums="1"
import from library.tools { tool_func }
import from library.sub.helper { help_func }
```