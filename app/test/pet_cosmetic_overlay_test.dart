import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/pet_cosmetic.dart';
import 'package:studysis/models/study_pet.dart';
import 'package:studysis/widgets/pet_cosmetic_overlay.dart';

void main() {
  test('fox young glasses are smaller and lower than headphones', () {
    final anchors = PetCosmeticAnchors.forPet(
      StudyPetId.fox,
      StudyPetGrowthStage.young,
      PetCosmeticPreviewContext.heroPreview,
    );

    final glasses = anchors.anchorFor(petCosmeticById('round_glasses')!);
    final headphones = anchors.anchorFor(petCosmeticById('study_headphones')!);

    expect(glasses.scale, lessThan(0.19));
    expect(glasses.dy, greaterThan(0.40));
    expect(headphones.scale, greaterThan(0.42));
    expect(headphones.dy, lessThan(glasses.dy));
  });

  test('fox leaf bow sits near one ear and scarf sits on chest', () {
    final anchors = PetCosmeticAnchors.forPet(
      StudyPetId.fox,
      StudyPetGrowthStage.young,
      PetCosmeticPreviewContext.heroPreview,
    );

    final bow = anchors.anchorFor(petCosmeticById('leaf_bow')!);
    final scarf = anchors.anchorFor(petCosmeticById('star_scarf')!);

    expect(bow.dx, lessThan(0.45));
    expect(bow.dy, lessThan(0.30));
    expect(scarf.dy, greaterThan(0.56));
  });

  test('shop preview anchors are slightly larger than hero anchors', () {
    final hero = PetCosmeticAnchors.forPet(
      StudyPetId.fox,
      StudyPetGrowthStage.young,
      PetCosmeticPreviewContext.heroPreview,
    ).anchorFor(petCosmeticById('study_headphones')!);
    final shop = PetCosmeticAnchors.forPet(
      StudyPetId.fox,
      StudyPetGrowthStage.young,
      PetCosmeticPreviewContext.shopPreview,
    ).anchorFor(petCosmeticById('study_headphones')!);

    expect(shop.scale, greaterThan(hero.scale));
    expect(shop.dy, greaterThan(hero.dy));
  });

  test('bunny head cosmetics sit above face but below long ear tips', () {
    final anchors = PetCosmeticAnchors.forPet(
      StudyPetId.bunny,
      StudyPetGrowthStage.young,
      PetCosmeticPreviewContext.heroPreview,
    );

    final cap = anchors.anchorFor(petCosmeticById('graduation_cap')!);
    final glasses = anchors.anchorFor(petCosmeticById('round_glasses')!);

    expect(cap.dy, lessThan(glasses.dy));
    expect(cap.dy, greaterThan(0.24));
  });

  test('cat face and head anchors reflect wider shorter-ear shape', () {
    final anchors = PetCosmeticAnchors.forPet(
      StudyPetId.cat,
      StudyPetGrowthStage.young,
      PetCosmeticPreviewContext.heroPreview,
    );

    final glasses = anchors.anchorFor(petCosmeticById('round_glasses')!);
    final hat = anchors.anchorFor(petCosmeticById('wizard_hat')!);

    expect(glasses.scale, greaterThanOrEqualTo(0.19));
    expect(glasses.dy, greaterThan(0.41));
    expect(hat.dy, lessThan(glasses.dy));
  });
}
