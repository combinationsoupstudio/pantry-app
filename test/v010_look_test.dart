import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pantry_app/ui/widgets/item_look.dart';

void main() {
  test('icons for what things are, not their first letter', () {
    final cases = <String, IconData>{
      'Bread': Icons.bakery_dining,
      'Rolled oats': Icons.breakfast_dining,
      'Eggs': Icons.egg,
      'UHT milk': Icons.local_drink,
      'Frozen peas': Icons.ac_unit,
      'Garlic': Icons.eco,
      'Potatoes washed loose': Icons.eco,
      'Tins: fish': Icons.inventory_2,
      'Tins: tomatoes': Icons.inventory_2,
      'Pasta': Icons.dinner_dining,
      'White rice': Icons.rice_bowl,
      'Batteries AAA': Icons.battery_full,
      'LED torch': Icons.flashlight_on,
      'Bandages': Icons.healing,
      'Panadol': Icons.medication,
      'Hydralyte sachets': Icons.medication_liquid,
      'Cask water 10 L': Icons.water_drop,
      'Tea bags': Icons.emoji_food_beverage,
      'Soy sauce': Icons.blender,
      'Canola oil': Icons.blender,
      'Nappies': Icons.child_care,
    };
    for (final MapEntry(key: name, value: icon) in cases.entries) {
      expect(lookFor(name).icon, icon, reason: name);
    }
  });

  test('where it is kept decides when the name says nothing', () {
    expect(lookFor('Thingamajig', locationId: 'medical').icon, Icons.medical_services);
    expect(lookFor('Thingamajig').icon, Icons.shopping_basket);
  });
}
