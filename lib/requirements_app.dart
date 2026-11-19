import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'models.dart';
import 'project_repository.dart';
import 'requirements_graph.dart';

const _titleBarMenuItemStyle = ButtonStyle(
  minimumSize: WidgetStatePropertyAll(Size.zero),
  padding: WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  ),
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 10)),
);

class RequirementsApp extends StatelessWidget {
  const RequirementsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Oth Requirements',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF176B87),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        dividerColor: const Color(0xFFDDE1E6),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        textTheme: Typography.material2021(platform: TargetPlatform.windows)
            .black
            .copyWith(
              displayLarge: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              displayMedium: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
              displaySmall: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              headlineLarge: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              headlineMedium: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              headlineSmall: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              bodyLarge: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              bodyMedium: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
              bodySmall: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
              labelLarge: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
              labelMedium: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
              ),
              labelSmall: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w400,
              ),
              titleLarge: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              titleMedium: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              titleSmall: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Color(0xFFDDE1E6)),
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          dense: true,
          minVerticalPadding: 5,
          visualDensity: VisualDensity.compact,
        ),
        buttonTheme: const ButtonThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      home: const _Workspace(),
    );
  }
}

class _Workspace extends StatefulWidget {
  const _Workspace();

  @override
  State<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<_Workspace> {
  ProjectRepository _repository = ProjectRepository();
  final TextEditingController _searchController = TextEditingController();
  RequirementProject? _project;
  Object? _loadError;
  int? _selectedFolderId;
  int? _selectedRequirementId;
  int? _highlightedRequirementId;
  int? _selectedCommentId;
  String _search = '';
  bool _saving = false;
  bool _variantsVisible = false;
  final Set<int> _expandedFolders = {1};
  final Set<int> _dirtyRequirements = {};
  final Set<int> _dirtyComments = {};
  final Map<int, Requirement> _requirementBaselines = {};
  bool _projectDirty = false;

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _rationaleController;
  late TextEditingController _commentController;

  RequirementProject get _data => _project!;

  bool get _hasChanges =>
      _projectDirty ||
      _dirtyRequirements.isNotEmpty ||
      _dirtyComments.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _rationaleController = TextEditingController();
    _commentController = TextEditingController();
    _loadProject();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _rationaleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadProject() async {
    try {
      final project = await _repository.load();
      if (!mounted) return;
      setState(() {
        _project = project;
        _selectedFolderId = project.folders.first.id;
        _selectedRequirementId = project.requirements.isEmpty
            ? null
            : project.requirements.first.id;
        _expandedFolders
          ..clear()
          ..addAll(
            project.folders
                .where((folder) => folder.parentId == null)
                .map((e) => e.id),
          );
        _requirementBaselines
          ..clear()
          ..addEntries(
            project.requirements.map(
              (requirement) => MapEntry(requirement.id, requirement.copy()),
            ),
          );
        _loadEditor();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
    }
  }

  void _loadEditor() {
    final requirement = _selectedRequirementId == null
        ? null
        : _data.requirement(_selectedRequirementId!);
    _titleController.text = requirement?.title ?? '';
    _descriptionController.text = requirement?.description ?? '';
    _rationaleController.text = requirement?.rationale ?? '';
    final comment = _selectedCommentId == null
        ? null
        : _data.comments.firstWhere((item) => item.id == _selectedCommentId);
    _commentController.text = comment?.description ?? '';
  }

  Requirement? get _activeRequirement => _selectedRequirementId == null
      ? null
      : _data.requirements
            .where((requirement) => requirement.id == _selectedRequirementId)
            .firstOrNull;

  Future<void> _saveProject() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repository.save(_data);
      if (!mounted) return;
      setState(() {
        _dirtyRequirements.clear();
        _dirtyComments.clear();
        _projectDirty = false;
        _requirementBaselines
          ..clear()
          ..addEntries(
            _data.requirements.map(
              (requirement) => MapEntry(requirement.id, requirement.copy()),
            ),
          );
      });
      _showMessage('Project saved');
    } catch (error) {
      _showMessage('Could not save project: $error', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscardChanges(String action) async {
    if (!_hasChanges) return true;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: Text('$action will discard the current unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<void> _openProject() async {
    if (!await _confirmDiscardChanges('Opening another project')) return;
    final result = await FilePicker.pickFile(
      dialogTitle: 'Open requirements project',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = result?.path;
    if (path == null) return;
    try {
      final repository = ProjectRepository(path: path);
      final project = await repository.load();
      if (!mounted) return;
      setState(() {
        _repository = repository;
        _setCurrentProject(project);
      });
      _showMessage('Opened ${project.name}');
    } catch (error) {
      _showMessage('Could not open project: $error', isError: true);
    }
  }

  Future<void> _saveProjectAs() async {
    final outputUri = await FilePicker.saveFile(
      dialogTitle: 'Save project as',
      fileName: '${_safeFileName(_data.name)}.json',
      bytes: Uint8List.fromList(utf8.encode(_data.toPrettyJson())),
      mimeType: 'application/json',
    );
    if (outputUri == null) return;
    setState(
      () => _repository = ProjectRepository(
        path: outputUri.toFilePath(windows: true),
      ),
    );
    await _saveProject();
  }

  void _setCurrentProject(RequirementProject project) {
    _project = project;
    _selectedFolderId = project.folders.first.id;
    _selectedRequirementId = null;
    _selectedCommentId = null;
    _highlightedRequirementId = null;
    _variantsVisible = false;
    _search = '';
    _searchController.clear();
    _expandedFolders
      ..clear()
      ..add(project.folders.first.id);
    _dirtyRequirements.clear();
    _dirtyComments.clear();
    _requirementBaselines
      ..clear()
      ..addEntries(
        project.requirements.map(
          (requirement) => MapEntry(requirement.id, requirement.copy()),
        ),
      );
    _projectDirty = false;
    _loadError = null;
    _loadEditor();
  }

  Future<void> _createProject() async {
    if (!await _confirmDiscardChanges('Creating a new project')) return;

    final name = await _promptForProjectName();
    if (name == null) return;

    try {
      final project = RequirementProject.empty(name: name);
      final outputUri = await FilePicker.saveFile(
        dialogTitle: 'Save new requirements project',
        fileName: '${_safeFileName(name)}.json',
        bytes: Uint8List.fromList(utf8.encode(project.toPrettyJson())),
        mimeType: 'application/json',
      );
      if (outputUri == null) return;
      final outputPath = outputUri.toFilePath(windows: true);
      final repository = ProjectRepository(path: outputPath);
      if (!mounted) return;
      setState(() {
        _repository = repository;
        _setCurrentProject(project);
      });
      _showMessage('Created $name');
    } catch (error) {
      _showMessage('Could not create project: $error', isError: true);
    }
  }

  Future<String?> _promptForProjectName() async {
    var name = 'New requirements project';
    final controller = TextEditingController(text: name)
      ..selection = TextSelection.collapsed(offset: name.length);
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create project'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Project name'),
            controller: controller,
            onChanged: (value) => setDialogState(() => name = value),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(context, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: name.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, name.trim()),
              child: const Text('Choose location'),
            ),
          ],
        ),
      ),
    );
    final result = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    return result;
  }

  String _safeFileName(String name) => name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .trim()
      .replaceAll(RegExp(r'\.+$'), '');

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  void _selectFolder(int id) {
    setState(() {
      _selectedFolderId = id;
      _selectedRequirementId = null;
      _selectedCommentId = null;
      _loadEditor();
    });
  }

  void _selectRequirement(int id, {bool focus = false}) {
    final folder = _data.containingFolder(id);
    setState(() {
      _selectedRequirementId = id;
      _selectedCommentId = null;
      _highlightedRequirementId = focus ? id : null;
      if (folder != null) {
        _selectedFolderId = folder.id;
        _expandedFolders.addAll(_data.ancestorsOfFolder(folder.id));
        _expandedFolders.add(folder.id);
      }
      _loadEditor();
    });
  }

  void _selectFromGraph(int id) {
    final folder = _data.containingFolder(id);
    setState(() {
      _selectedRequirementId = id;
      _selectedCommentId = null;
      _highlightedRequirementId = id;
      if (folder != null) {
        _expandedFolders.addAll(_data.ancestorsOfFolder(folder.id));
        _expandedFolders.add(folder.id);
      }
      _loadEditor();
    });
  }

  void _selectComment(int id) {
    final comment = _data.comments.firstWhere((item) => item.id == id);
    final folder = _data.folders.firstWhere(
      (item) => item.commentIds.contains(id),
    );
    setState(() {
      _selectedCommentId = id;
      _selectedRequirementId = null;
      _selectedFolderId = folder.id;
      _highlightedRequirementId = comment.attachedToId;
      _loadEditor();
    });
  }

  void _addRequirement() {
    if (_selectedFolderId == null) return;
    final requirement = _data.createRequirement(_selectedFolderId!);
    _requirementBaselines[requirement.id] = requirement.copy();
    _dirtyRequirements.add(requirement.id);
    _projectDirty = true;
    _expandedFolders.add(_selectedFolderId!);
    _selectRequirement(requirement.id, focus: true);
  }

  void _addFolder() {
    if (_selectedFolderId == null) return;
    final child = _data.createFolder(_selectedFolderId!);
    setState(() {
      _projectDirty = true;
      _expandedFolders.add(_selectedFolderId!);
      _selectedFolderId = child.id;
      _selectedRequirementId = null;
      _selectedCommentId = null;
      _loadEditor();
    });
  }

  Future<void> _renameFolder(int folderId) async {
    final folder = _data.folder(folderId);
    final controller = TextEditingController(text: folder.name)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: folder.name.length,
      );
    final route = DialogRoute<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rename folder'),
          content: TextField(
            autofocus: true,
            controller: controller,
            decoration: const InputDecoration(labelText: 'Folder name'),
            onChanged: (_) => setDialogState(() {}),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                Navigator.pop(context, value.trim());
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Rename'),
            ),
          ],
        ),
      ),
    );
    final name = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    if (name == null || name == folder.name) return;
    setState(() {
      folder.name = name;
      _projectDirty = true;
    });
  }

  void _addComment() {
    if (_selectedFolderId == null || _selectedRequirementId == null) return;
    final comment = _data.createComment(
      _selectedFolderId!,
      _selectedRequirementId!,
    );
    _dirtyComments.add(comment.id);
    _projectDirty = true;
    _selectComment(comment.id);
  }

  void _markRequirementDirty() {
    final requirement = _activeRequirement;
    if (requirement == null) return;
    _dirtyRequirements.add(requirement.id);
    setState(() {});
  }

  void _discardRequirementChanges() {
    final id = _selectedRequirementId;
    if (id == null) return;
    final current = _data.requirement(id);
    final baseline = _requirementBaselines[id];
    if (baseline != null) {
      current.title = baseline.title;
      current.description = baseline.description;
      current.rationale = baseline.rationale;
      current.variantId = baseline.variantId;
      current.outgoingIds = List<int>.from(baseline.outgoingIds);
    }
    _loadEditor();
    setState(() => _dirtyRequirements.remove(id));
    _showMessage('Changes discarded');
  }

  List<int> get _graphIds {
    if (_selectedRequirementId != null) {
      final selected = _data.requirement(_selectedRequirementId!);
      return <int>{
        selected.id,
        ...selected.outgoingIds,
        ..._data.requirements
            .where((item) => item.outgoingIds.contains(selected.id))
            .map((item) => item.id),
      }.where((id) => _data.requirements.any((item) => item.id == id)).toList();
    }
    if (_selectedCommentId != null) {
      final comment = _data.comments.firstWhere(
        (item) => item.id == _selectedCommentId,
      );
      return [comment.attachedToId];
    }
    if (_selectedFolderId != null) {
      return List<int>.from(_data.folder(_selectedFolderId!).requirementIds);
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Could not open the project database.\n$_loadError'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadProject, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_project == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Column(
        children: [
          _buildTitleBar(context),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 286, child: _buildExplorer(context)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        flex: 6,
                        child: _variantsVisible
                            ? _buildVariantTable(context)
                            : RequirementsGraph(
                                project: _data,
                                requirementIds: _graphIds,
                                selectedId: _selectedRequirementId,
                                highlightedId: _highlightedRequirementId,
                                onSelect: _selectFromGraph,
                              ),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        height: 280,
                        child: _selectedCommentId != null
                            ? _buildCommentEditor(context)
                            : _buildRequirementEditor(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final title = '${_data.name} — ${_repository.path}';
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      behavior: HitTestBehavior.translucent,
      child: Container(
        height: 34,
        color: const Color(0xFFF3F3F3),
        child: Row(
          children: [
            MenuAnchor(
              style: const MenuStyle(
                padding: WidgetStatePropertyAll(EdgeInsets.zero),
                minimumSize: WidgetStatePropertyAll(Size.zero),
                maximumSize: WidgetStatePropertyAll(Size.fromHeight(300)),
              ),
              menuChildren: [
                MenuItemButton(
                  style: _titleBarMenuItemStyle,
                  leadingIcon: const Icon(Icons.folder_open_outlined),
                  onPressed: _openProject,
                  child: const Text('Open Project'),
                ),
                MenuItemButton(
                  style: _titleBarMenuItemStyle,
                  leadingIcon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: _createProject,
                  child: const Text('Create Project'),
                ),
                MenuItemButton(
                  style: _titleBarMenuItemStyle,
                  leadingIcon: const Icon(Icons.save_outlined),
                  onPressed: _saving ? null : _saveProject,
                  child: const Text('Save Project'),
                ),
                MenuItemButton(
                  style: _titleBarMenuItemStyle,
                  leadingIcon: const Icon(Icons.save_as_outlined),
                  onPressed: _saveProjectAs,
                  child: const Text('Save Project as'),
                ),
              ],
              builder: (context, controller, child) => TextButton(
                onPressed: controller.isOpen
                    ? controller.close
                    : controller.open,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 10),
                ),
                child: const Text('File'),
              ),
            ),
            MenuAnchor(
              style: const MenuStyle(
                padding: WidgetStatePropertyAll(EdgeInsets.zero),
                minimumSize: WidgetStatePropertyAll(Size.zero),
                maximumSize: WidgetStatePropertyAll(Size.fromHeight(300)),
              ),
              menuChildren: [
                MenuItemButton(
                  style: _titleBarMenuItemStyle,
                  leadingIcon: const Icon(Icons.layers_outlined),
                  onPressed: () => setState(() => _variantsVisible = true),
                  child: const Text('Open Variant Editor'),
                ),
              ],
              builder: (context, controller, child) => TextButton(
                onPressed: controller.isOpen
                    ? controller.close
                    : controller.open,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  textStyle: const TextStyle(fontSize: 10),
                ),
                child: const Text('Variant'),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            _WindowControl(
              icon: Icons.remove,
              tooltip: 'Minimize',
              onPressed: windowManager.minimize,
            ),
            _WindowControl(
              icon: Icons.crop_square,
              tooltip: 'Maximize',
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            _WindowControl(
              icon: Icons.close,
              tooltip: 'Close',
              destructive: true,
              onPressed: windowManager.close,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplorer(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('EXPLORER', style: TextStyle(fontSize: 10)),
                ),
                _IconButton(
                  tooltip: 'Add requirement',
                  icon: Icons.note_add_outlined,
                  onPressed: _selectedFolderId == null ? null : _addRequirement,
                ),
                _IconButton(
                  tooltip: 'Add folder',
                  icon: Icons.create_new_folder_outlined,
                  onPressed: _selectedFolderId == null ? null : _addFolder,
                ),
                _IconButton(
                  tooltip: 'Add comment to selected requirement',
                  icon: Icons.add_comment_outlined,
                  onPressed: _selectedRequirementId == null
                      ? null
                      : _addComment,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _search = value),
              decoration: InputDecoration(
                hintText: 'Search: id:, version:, or text',
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                      ),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: _data.folders
                  .where((folder) => folder.parentId == null)
                  .map((folder) => _buildFolder(folder.id, 0))
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${_data.requirements.length} requirements  •  ${_dirtyRequirements.length + _dirtyComments.length} modified',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolder(int folderId, int depth) {
    final folder = _data.folder(folderId);
    final visibleRequirements = folder.requirementIds
        .where(_matchesRequirement)
        .toList();
    final visibleComments = folder.commentIds.where(_matchesComment).toList();
    final expanded = _expandedFolders.contains(folderId) || _search.isNotEmpty;
    final folderMatches = _folderMatches(folderId);
    if (_search.isNotEmpty &&
        visibleRequirements.isEmpty &&
        visibleComments.isEmpty &&
        !folderMatches) {
      return const SizedBox.shrink();
    }
    return Column(
      children: [
        _ExplorerRow(
          depth: depth,
          selected:
              _selectedFolderId == folderId &&
              _selectedRequirementId == null &&
              _selectedCommentId == null,
          icon: expanded ? Icons.folder_open : Icons.folder_outlined,
          label: folder.name,
          onTap: () => _selectFolder(folderId),
          onDoubleTap: () => _renameFolder(folderId),
          trailingAction: IconButton(
            tooltip: 'Rename folder',
            icon: const Icon(Icons.edit_outlined, size: 16),
            visualDensity: VisualDensity.compact,
            onPressed: () => _renameFolder(folderId),
          ),
          leadingAction: IconButton(
            tooltip: expanded ? 'Collapse folder' : 'Expand folder',
            icon: Icon(
              expanded ? Icons.expand_more : Icons.chevron_right,
              size: 16,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() {
              if (expanded) {
                _expandedFolders.remove(folderId);
              } else {
                _expandedFolders.add(folderId);
              }
            }),
          ),
        ),
        if (expanded)
          for (final child in folder.childFolderIds)
            _buildFolder(child, depth + 1),
        if (expanded)
          for (final id in visibleRequirements)
            _ExplorerRow(
              depth: depth + 1,
              selected: _selectedRequirementId == id,
              highlighted: _highlightedRequirementId == id,
              dirty: _dirtyRequirements.contains(id),
              icon: Icons.description_outlined,
              label:
                  '${_data.requirement(id).displayId}  ${_data.requirement(id).title}',
              onTap: () => _selectRequirement(id, focus: true),
            ),
        if (expanded)
          for (final id in visibleComments)
            _ExplorerRow(
              depth: depth + 1,
              selected: _selectedCommentId == id,
              dirty: _dirtyComments.contains(id),
              icon: Icons.chat_bubble_outline,
              label:
                  'Comment  ${_data.comments.firstWhere((item) => item.id == id).description}',
              onTap: () => _selectComment(id),
            ),
      ],
    );
  }

  bool _matchesRequirement(int id) {
    if (_search.isEmpty) return true;
    final query = _search.trim().toLowerCase();
    final requirement = _data.requirement(id);
    if (query.startsWith('id:')) {
      return requirement.displayId.toLowerCase().contains(
        query.substring(3).trim(),
      );
    }
    if (query.startsWith('version:')) {
      return _data
          .variant(requirement.variantId)
          .name
          .toLowerCase()
          .contains(query.substring(8).trim());
    }
    final commentText = _data.comments
        .where((comment) => comment.attachedToId == id)
        .map((comment) => comment.description)
        .join(' ');
    return _matchesText(
      '${requirement.displayId} ${requirement.title} ${requirement.description} '
      '${requirement.rationale} $commentText',
    );
  }

  bool _matchesComment(int id) =>
      _search.isEmpty ||
      _matchesText(
        _data.comments.firstWhere((comment) => comment.id == id).description,
      );

  bool _folderMatches(int folderId) {
    final folder = _data.folder(folderId);
    return _matchesText('${folder.name} ${folder.description}') ||
        folder.requirementIds.any(_matchesRequirement) ||
        folder.commentIds.any(_matchesComment) ||
        folder.childFolderIds.any(_folderMatches);
  }

  bool _matchesText(String value) =>
      value.toLowerCase().contains(_search.trim().toLowerCase());

  Widget _buildRequirementEditor(BuildContext context) {
    final requirement = _activeRequirement;
    if (requirement == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app_outlined, size: 30),
            const SizedBox(height: 8),
            Text(
              _selectedFolderId == null
                  ? 'Select an item in the explorer.'
                  : 'Select a requirement in “${_data.folder(_selectedFolderId!).name}” to edit it.',
            ),
          ],
        ),
      );
    }
    final incoming = _data.requirements
        .where((item) => item.outgoingIds.contains(requirement.id))
        .toList();
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(flex: 7, child: _buildEditableColumn(context, requirement)),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: _buildRelations(
              context,
              title: 'Outgoing · specifies',
              requirements: requirement.outgoingIds
                  .map(_data.requirement)
                  .toList(),
              editable: true,
              onAdd: () => _showAddRelation(requirement),
              onRemove: (id) {
                setState(() => requirement.outgoingIds.remove(id));
                _markRequirementDirty();
              },
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            flex: 3,
            child: _buildRelations(
              context,
              title: 'Incoming',
              requirements: incoming,
              editable: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableColumn(BuildContext context, Requirement requirement) {
    final dirty = _dirtyRequirements.contains(requirement.id);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Focus requirement',
                icon: const Icon(Icons.adjust),
                onPressed: () =>
                    _selectRequirement(requirement.id, focus: true),
              ),
              Text(requirement.displayId),
              if (dirty)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.circle, size: 8),
                ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _titleController,
                  onChanged: (value) {
                    requirement.title = value;
                    _markRequirementDirty();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int>(
                  initialValue: requirement.variantId,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Variant',
                    border: OutlineInputBorder(),
                  ),
                  items: _data.variants
                      .map(
                        (variant) => DropdownMenuItem(
                          value: variant.id,
                          child: Text(variant.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    requirement.variantId = value;
                    _markRequirementDirty();
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Discard',
                onPressed: dirty ? _discardRequirementChanges : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton.filled(
                tooltip: 'Save',
                onPressed: dirty ? _saveProject : null,
                icon: const Icon(Icons.save_outlined),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _EditorField(
                    label: 'Description',
                    controller: _descriptionController,
                    onChanged: (value) {
                      requirement.description = value;
                      _markRequirementDirty();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _EditorField(
                    label: 'Rationale',
                    controller: _rationaleController,
                    onChanged: (value) {
                      requirement.rationale = value;
                      _markRequirementDirty();
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelations(
    BuildContext context, {
    required String title,
    required List<Requirement> requirements,
    required bool editable,
    VoidCallback? onAdd,
    ValueChanged<int>? onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.all(7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 10)),
              ),
              if (editable)
                IconButton(
                  tooltip: 'Add relation',
                  icon: const Icon(Icons.add, size: 18),
                  onPressed: onAdd,
                ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 4),
          if (requirements.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Text('No relations', textAlign: TextAlign.center),
            ),
          Expanded(
            child: ListView(
              children: requirements
                  .map(
                    (item) => ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 8),
                      title: Text(item.displayId),
                      subtitle: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectRequirement(item.id, focus: true),
                      trailing: editable
                          ? IconButton(
                              tooltip: 'Remove relation',
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => onRemove?.call(item.id),
                            )
                          : null,
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddRelation(Requirement source) async {
    final controller = TextEditingController();
    var query = '';
    final route = DialogRoute<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final available = _data.requirements
              .where(
                (item) =>
                    item.id != source.id &&
                    !source.outgoingIds.contains(item.id),
              )
              .where((item) {
                final search = query.trim().toLowerCase();
                return '${item.displayId} ${item.title}'.toLowerCase().contains(
                  search,
                );
              })
              .toList();
          return AlertDialog(
            title: const Text('Add specifies relation'),
            content: SizedBox(
              width: 480,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (value) => setDialogState(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'Search by ID or title',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                controller.clear();
                                setDialogState(() => query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: available.isEmpty
                        ? const Center(child: Text('No requirements found'))
                        : ListView.separated(
                            itemCount: available.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = available[index];
                              return ListTile(
                                onTap: () => Navigator.pop(context, item.id),
                                leading: const Icon(Icons.description_outlined),
                                title: Text(item.displayId),
                                subtitle: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.add),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
    final selected = await Navigator.of(context).push(route);
    await route.completed;
    controller.dispose();
    if (selected == null) return;
    setState(() => source.outgoingIds.add(selected));
    _markRequirementDirty();
  }

  Widget _buildCommentEditor(BuildContext context) {
    final comment = _data.comments.firstWhere(
      (item) => item.id == _selectedCommentId,
    );
    final dirty = _dirtyComments.contains(comment.id);
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Comment on ${_data.requirement(comment.attachedToId).displayId}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                if (dirty)
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () =>
                      _selectRequirement(comment.attachedToId, focus: true),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open requirement'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: dirty ? _saveProject : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: _EditorField(
                label: 'Description',
                controller: _commentController,
                onChanged: (value) {
                  comment.description = value;
                  setState(() => _dirtyComments.add(comment.id));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantTable(BuildContext context) {
    final roots = _data.variants
        .where((variant) => variant.parentId == 0)
        .toList();
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _variantsVisible = false),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Back to graph'),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text('Variants', style: TextStyle(fontSize: 13)),
              ),
              FilledButton.icon(
                onPressed: () => _showVariantDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add variant'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                for (final root in roots)
                  _VariantBranch(
                    project: _data,
                    variant: root,
                    depth: 0,
                    onEdit: (variant) => _showVariantDialog(variant: variant),
                    onDelete: (variant) => _deleteVariant(variant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showVariantDialog({RequirementVariant? variant}) async {
    final name = TextEditingController(text: variant?.name ?? '');
    final description = TextEditingController(text: variant?.description ?? '');
    int parentId =
        variant?.parentId ??
        (_data.variants.isEmpty ? 0 : _data.variants.first.id);
    final excludedParents = variant == null
        ? <int>{}
        : _variantAndDescendantIds(variant.id);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(variant == null ? 'Create variant' : 'Edit variant'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  minLines: 2,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: parentId,
                  decoration: const InputDecoration(
                    labelText: 'Parent variant',
                  ),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('No parent')),
                    ..._data.variants
                        .where((item) => !excludedParents.contains(item.id))
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ),
                        ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => parentId = value ?? 0),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: name.text.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (result != true) return;
    setState(() {
      if (variant == null) {
        _data.variants.add(
          RequirementVariant(
            id: _data.nextEntityId++,
            parentId: parentId,
            name: name.text.trim(),
            description: description.text.trim(),
          ),
        );
      } else {
        variant.name = name.text.trim();
        variant.description = description.text.trim();
        variant.parentId = parentId;
      }
    });
    await _saveProject();
  }

  Set<int> _variantAndDescendantIds(int rootId) {
    final result = <int>{};
    final pending = <int>[rootId];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!result.add(id)) continue;
      pending.addAll(
        _data.variants
            .where((variant) => variant.parentId == id)
            .map((variant) => variant.id),
      );
    }
    return result;
  }

  Future<void> _deleteVariant(RequirementVariant variant) async {
    if (!_data.canDeleteVariant(variant.id)) {
      _showMessage('This variant is assigned to a requirement.', isError: true);
      return;
    }
    if (_data.variants.any((item) => item.parentId == variant.id)) {
      _showMessage('Delete child variants before this variant.', isError: true);
      return;
    }
    setState(() => _data.variants.removeWhere((item) => item.id == variant.id));
    await _saveProject();
  }
}

class _ExplorerRow extends StatelessWidget {
  const _ExplorerRow({
    required this.depth,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.highlighted = false,
    this.dirty = false,
    this.leadingAction,
    this.trailingAction,
    this.onDoubleTap,
  });

  final int depth;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool highlighted;
  final bool dirty;
  final Widget? leadingAction;
  final Widget? trailingAction;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primaryContainer
          : highlighted
          ? Colors.teal.withValues(alpha: 0.13)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: SizedBox(
          height: 29,
          child: Padding(
            padding: EdgeInsets.only(left: 7 + depth * 18.0, right: 8),
            child: Row(
              children: [
                if (leadingAction != null)
                  SizedBox(width: 24, child: leadingAction)
                else
                  const SizedBox(width: 24),
                Icon(
                  icon,
                  size: 17,
                  color: highlighted ? Colors.teal.shade700 : null,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (dirty) Icon(Icons.circle, size: 7, color: scheme.primary),
                if (trailingAction != null)
                  SizedBox(width: 26, child: trailingAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      expands: true,
      minLines: null,
      maxLines: null,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: true,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _VariantBranch extends StatelessWidget {
  const _VariantBranch({
    required this.project,
    required this.variant,
    required this.depth,
    required this.onEdit,
    required this.onDelete,
  });

  final RequirementProject project;
  final RequirementVariant variant;
  final int depth;
  final ValueChanged<RequirementVariant> onEdit;
  final ValueChanged<RequirementVariant> onDelete;

  @override
  Widget build(BuildContext context) {
    final children = project.variants
        .where((item) => item.parentId == variant.id)
        .toList();
    final usage = project.requirements
        .where((item) => item.variantId == variant.id)
        .length;
    return Column(
      children: [
        Card(
          margin: EdgeInsets.only(left: depth * 28.0, bottom: 8),
          child: ListTile(
            leading: Icon(
              depth == 0 ? Icons.layers : Icons.subdirectory_arrow_right,
            ),
            title: Text(variant.name),
            subtitle: Text(
              '${variant.description}\n$usage requirement${usage == 1 ? '' : 's'} assigned',
            ),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Edit variant',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => onEdit(variant),
                ),
                IconButton(
                  tooltip: 'Delete variant',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: usage == 0 && children.isEmpty
                      ? () => onDelete(variant)
                      : null,
                ),
              ],
            ),
          ),
        ),
        for (final child in children)
          _VariantBranch(
            project: project,
            variant: child,
            depth: depth + 1,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon, size: 19),
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
  );
}

class _WindowControl extends StatelessWidget {
  const _WindowControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 34,
    child: IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 14),
      onPressed: onPressed,
      style: ButtonStyle(
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? (destructive ? const Color(0xFFC42B1C) : Colors.black12)
              : null,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => destructive && states.contains(WidgetState.hovered)
              ? Colors.white
              : Colors.black87,
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
    ),
  );
}
