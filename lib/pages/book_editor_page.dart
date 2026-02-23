import 'package:book_app_themed/models/book.dart';
import 'package:book_app_themed/utils/date_formatters.dart';
import 'package:book_app_themed/widgets/section_card.dart';
import 'package:flutter/cupertino.dart';

class BookEditorPage extends StatefulWidget {
  const BookEditorPage({super.key, this.existing});

  final BookItem? existing;

  @override
  State<BookEditorPage> createState() => _BookEditorPageState();
}

class _BookEditorPageState extends State<BookEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _pageCountController;
  late final TextEditingController _notesController;

  late BookStatus _status;
  late ReadingMedium _medium;
  late int _rating;
  late double _progress;
  DateTime? _startDate;
  DateTime? _endDate;

  bool get _canSave => _titleController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final book = widget.existing;
    _titleController = TextEditingController(text: book?.title ?? '');
    _authorController = TextEditingController(text: book?.author ?? '');
    _coverUrlController = TextEditingController(text: book?.coverUrl ?? '');
    _pageCountController = TextEditingController(
      text: book != null && book.pageCount > 0 ? '${book.pageCount}' : '',
    );
    _notesController = TextEditingController(text: book?.notes ?? '');
    _status = book?.status ?? BookStatus.readingList;
    _medium = book?.medium ?? ReadingMedium.physicalBook;
    _rating = book?.rating ?? 0;
    _progress = (book?.progressPercent ?? 0).toDouble();
    _startDate = parseDateOnlyIso(book?.startDateIso);
    _endDate = parseDateOnlyIso(book?.endDateIso);

    _titleController.addListener(_rebuild);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_rebuild)
      ..dispose();
    _authorController.dispose();
    _coverUrlController.dispose();
    _pageCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _pickStartDate() async {
    final picked = await _showDatePicker(initialDate: _startDate);
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(_startDate!)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await _showDatePicker(initialDate: _endDate ?? _startDate);
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<DateTime?> _showDatePicker({DateTime? initialDate}) async {
    DateTime selected = initialDate ?? DateTime.now();
    final result = await showCupertinoModalPopup<DateTime>(
      context: context,
      builder: (context) {
        return Container(
          height: 300,
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: Column(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.separator.resolveFrom(context),
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: <Widget>[
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size.square(28),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size.square(28),
                      onPressed: () => Navigator.of(context).pop(selected),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: selected,
                  maximumYear: DateTime.now().year + 20,
                  minimumYear: 1900,
                  onDateTimeChanged: (value) => selected = value,
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return null;
    return DateTime(result.year, result.month, result.day);
  }

  void _save() {
    if (!_canSave) return;
    final pageCount = int.tryParse(_pageCountController.text.trim()) ?? 0;
    final progress = _progress.round().clamp(0, 100).toInt();

    Navigator.of(context).pop(
      BookDraft(
        title: _titleController.text,
        author: _authorController.text,
        notes: _notesController.text,
        coverUrl: _coverUrlController.text,
        status: _status,
        rating: _rating,
        pageCount: pageCount < 0 ? 0 : pageCount,
        progressPercent: progress,
        medium: _medium,
        startDateIso: _startDate == null ? null : toDateOnlyIso(_startDate!),
        endDateIso: _endDate == null ? null : toDateOnlyIso(_endDate!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isEditing ? 'Edit Book' : 'Add Book'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(28),
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Cancel'),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(28),
          onPressed: _canSave ? _save : null,
          child: const Text('Save'),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: <Widget>[
            SectionCard(
              title: 'Book',
              child: Column(
                children: <Widget>[
                  const _FieldLabel('Title'),
                  CupertinoTextField(
                    controller: _titleController,
                    placeholder: 'Book title',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: _fieldDecoration(context),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel('Author'),
                  CupertinoTextField(
                    controller: _authorController,
                    placeholder: 'Author name',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: _fieldDecoration(context),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel('Cover Image URL'),
                  CupertinoTextField(
                    controller: _coverUrlController,
                    placeholder: 'https://example.com/cover.jpg',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: _fieldDecoration(context),
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel('Page Count'),
                  CupertinoTextField(
                    controller: _pageCountController,
                    placeholder: 'e.g. 320',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: _fieldDecoration(context),
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  ),
                  const SizedBox(height: 10),
                  const _FieldLabel('Notes'),
                  CupertinoTextField(
                    controller: _notesController,
                    placeholder: 'Notes about this book',
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: _fieldDecoration(context),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Reading Status',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  CupertinoSlidingSegmentedControl<BookStatus>(
                    groupValue: _status,
                    onValueChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                    children: const <BookStatus, Widget>{
                      BookStatus.reading: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Text('Reading', style: TextStyle(fontSize: 12)),
                      ),
                      BookStatus.read: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Text('Read', style: TextStyle(fontSize: 12)),
                      ),
                      BookStatus.readingList: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: Text('Reading List', style: TextStyle(fontSize: 12)),
                      ),
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Progress: ${_progress.round()}%',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  CupertinoSlider(
                    value: _progress,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    onChanged: (value) => setState(() => _progress = value),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Rating',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: List<Widget>.generate(5, (index) {
                      final value = index + 1;
                      final active = value <= _rating;
                      return CupertinoButton(
                        padding: const EdgeInsets.only(right: 4),
                        minimumSize: const Size.square(30),
                        onPressed: () => setState(() {
                          _rating = active && _rating == value ? value - 1 : value;
                        }),
                        child: Icon(
                          active ? CupertinoIcons.star_fill : CupertinoIcons.star,
                          color: active
                              ? CupertinoColors.systemYellow
                              : CupertinoColors.systemGrey3.resolveFrom(context),
                          size: 22,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Reading Details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Medium',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReadingMedium.values.map((medium) {
                      final selected = _medium == medium;
                      return _ChoiceChipButton(
                        icon: medium.icon,
                        label: medium.label,
                        selected: selected,
                        onPressed: () => setState(() => _medium = medium),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  _DateRow(
                    icon: CupertinoIcons.calendar,
                    label: 'Start Date',
                    value: _startDate == null ? 'Not set' : formatDateShort(toDateOnlyIso(_startDate!)),
                    onPick: _pickStartDate,
                    onClear: _startDate == null ? null : () => setState(() => _startDate = null),
                  ),
                  const SizedBox(height: 10),
                  _DateRow(
                    icon: CupertinoIcons.calendar_today,
                    label: 'End Date',
                    value: _endDate == null ? 'Not set' : formatDateShort(toDateOnlyIso(_endDate!)),
                    onPick: _pickEndDate,
                    onClear: _endDate == null ? null : () => setState(() => _endDate = null),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _fieldDecoration(BuildContext context) {
  return BoxDecoration(
    color: CupertinoColors.systemBackground.resolveFrom(context),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: CupertinoColors.separator.resolveFrom(context).withOpacity(0.35),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  const _ChoiceChipButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final border = CupertinoColors.separator.resolveFrom(context);
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 0),
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? CupertinoColors.activeBlue.withOpacity(0.16)
              : CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? CupertinoColors.activeBlue : border.withOpacity(0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 14,
              color: selected
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? CupertinoColors.activeBlue
                    : CupertinoColors.label.resolveFrom(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final border = CupertinoColors.separator.resolveFrom(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border.withOpacity(0.25)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: CupertinoColors.secondaryLabel.resolveFrom(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.label.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size.square(28),
            onPressed: onPick,
            child: const Text('Pick'),
          ),
          if (onClear != null)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size.square(28),
              onPressed: onClear,
              child: const Icon(
                CupertinoIcons.clear_circled_solid,
                size: 18,
                color: CupertinoColors.systemRed,
              ),
            ),
        ],
      ),
    );
  }
}
