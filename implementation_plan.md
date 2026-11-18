# Othmerding Requirement


# Variants
Variants offers a mechanism to describe different but similar System in the same Project to avoid duplication.
Variants shall be structured as a Tree. This enables us to have more granular Groups of Systems that share requirements. 
Every Requirement shall have a Variant.
A Variant cannot be deleted, as long as a Requirement still has the Variant selected.

# UI

# Graph
Purely a Display. 
Displays the selected Requirement or all Requirement within a Folder but not the subfolders of the folder.
If a Requirement is selected, construct a graph with all other Requirements this one points too or is pointed by.
Only display related Requirement with a direct connection.
Show the connections as connecting arrows.
Clicking a Requirement shall Open it in the Requirement Editor and Highlight in the Graph.
When a Requirement is clicked in the Graph, the Navigation in the Explorer shall also jump to this requirement.
The Requirement shall be highlighted in the Explorer, but shall not be automatically selected.  
Use different colors for Selection and Highlighting. 
Use Graphviz for automated graph Layout.
Connecting lines shall only be in the orthogonal style.

# Explorer
Displays Folders and Requirements.
Folder shall be Expandable.
Shall be structured like the Explorer of VSCode.
With Requirements being equivalent to Files.

## Adding a Subfolder/Requirement
Above the root folder shall be a button to Add a Requirement and one to add a Folder.
The added Element shall be added to the currently selected folder.
If no folder is selected, the Add buttons shall be deactivated.

# Variant
The Variant tree shall be accessable through a button on the Top Bar.
The Variant Viewer shall be a table with Splitting columns for every sub Variant.

# Search
The search Bar shall be above the Explorer.
Shall support searching by ID, Version or free text search.
Free Text Search shall serach everything (Comment, Descriptions, Rationales, Titles)
Version serach shall begin with version:
ID search with id:

# Requirement Editor

The Requirement Editor component shall be placed below the Graph view.
The Editor shall contain three columns.
The first column contains four rows.
The first row Contains the Focus Button, the ID and the editable title.
The second the Variant selector (dropdown menu) and the Drop Changes and Save Button.
The Second Row contains the description.
The third the Rationale.


The Second column Contains the Outgoing relations (Specifies) as a list.
With a "+" button on the Top to add another.
Relations shall have a Delete button next to it.

The third column shall be the incoming connection.
These cannot be edited.

Relating Requirements shall be displayed with ID and Title in incoming and outgoing.
Clicking on any Relation (outgoing or incoming) shall highlight the relating Requirement in the Graph and Explorer view. 

Clicking the focus button shall select a Requirement in the Explorer.
It shall have the same effect as clicking it in the Explorer.
The Graph shall be rebuild around this requirement.

The Third column shall contain the Reference Search.

# Unsaved Changes
Every unsaved change shall be Marked with a dot.
This shall be the case for Editable field in the Requirement Editor.
But also in the Explorer and the Tree view.


# Implementation

Create the Graph Layout using Graphviz
Create a schema that uses the examples in the example_jsons folders.
Use one large Json File as Project Database.
Use Python 3.14.
Use Flet.
Unit test all non UI Code.
Use Icons from the flet package.