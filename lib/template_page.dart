import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'providers.dart';

class TemplatePage extends ConsumerWidget {
  final bool selectMode;

  const TemplatePage({
    super.key,
    this.selectMode = false,
  });

  Future<void> _editTemplate(
    BuildContext context,
    WidgetRef ref, {
    DiaryTemplate? template,
  }) async {
    final nameController = TextEditingController(
      text: template?.name ?? '',
    );

    final contentController = TextEditingController(
      text: template?.content ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            template == null ? '新增模板' : '編輯模板',
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '模板名稱',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '模板內容',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('儲存'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      nameController.dispose();
      contentController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final content = contentController.text;

    if (name.isEmpty || content.trim().isEmpty) {
      nameController.dispose();
      contentController.dispose();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('模板名稱與內容不能為空'),
          ),
        );
      }

      return;
    }

    final repository =
        ref.read(diaryRepositoryProvider);

    final now = DateTime.now();

    if (template == null) {
      await repository.insertTemplate(
        DiaryTemplate(
          name: name,
          content: content,
          createdAt: now,
          updatedAt: now,
        ),
      );
    } else {
      await repository.updateTemplate(
        DiaryTemplate(
          id: template.id,
          name: name,
          content: content,
          isDefault: template.isDefault,
          createdAt: template.createdAt,
          updatedAt: now,
        ),
      );
    }

    nameController.dispose();
    contentController.dispose();

    ref.invalidate(templateListProvider);
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    DiaryTemplate template,
  ) async {
    if (template.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('內建模板不能刪除'),
        ),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('刪除模板'),
          content: Text(
            '確定要刪除「${template.name}」嗎？',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (result != true) return;

    await ref
        .read(diaryRepositoryProvider)
        .deleteTemplate(template.id!);

    ref.invalidate(templateListProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(templateListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectMode ? '選擇模板' : '日記模板',
        ),
        actions: [
          if (!selectMode)
            IconButton(
              onPressed: () {
                _editTemplate(context, ref);
              },
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: templates.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Text('讀取失敗：$error'),
        ),
        data: (items) {
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final template = items[index];

              return Card(
                child: ListTile(
                  leading: Icon(
                    template.isDefault
                        ? Icons.description
                        : Icons.article_outlined,
                  ),
                  title: Text(template.name),
                  subtitle: Text(
                    template.content.replaceAll(
                      '\n',
                      ' ',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: selectMode
                      ? const Icon(
                          Icons.chevron_right,
                        )
                      : PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _editTemplate(
                                context,
                                ref,
                                template: template,
                              );
                            }

                            if (value == 'delete') {
                              _deleteTemplate(
                                context,
                                ref,
                                template,
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('編輯'),
                            ),
                            if (!template.isDefault)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('刪除'),
                              ),
                          ],
                        ),
                  onTap: () {
                    if (selectMode) {
                      Navigator.pop(
                        context,
                        template.content,
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}