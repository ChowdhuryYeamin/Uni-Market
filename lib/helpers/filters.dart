import 'package:flutter/material.dart';

enum Sort {
  lowToHigh,
  highToLow,
  bestMatch,
  newestToOldest,
  oldestToNewest,
}

enum Condition { newItem, usedItem, wornItem, none }

class Filters {
  int lowerPrice;
  int upperPrice;
  List<bool?> tags;
  Sort sort;
  Condition condition;
  Filters(
      this.lowerPrice, this.upperPrice, this.tags, this.sort, this.condition);
  Filters.none()
      : lowerPrice = 0,
        upperPrice = 100000,
        tags = [false, false, false, false],
        sort = Sort.bestMatch,
        condition = Condition.none;
}
