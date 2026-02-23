import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BrandAppIcon extends StatelessWidget {
  const BrandAppIcon({
    super.key,
    this.size = 36,
    this.borderRadius = 12,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey6.resolveFrom(context),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: SvgPicture.asset(
          'assets/icons/blackpiratex_book_tracker_icon.svg',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
