# Flamewarden illustration

`flamewarden_atlas.png` is original AI-generated artwork created for this project with OpenAI image generation on 2026-11-20. It is a transparent 1254 × 1254 RGBA atlas of sixteen separated painted character parts. No third-party character assets were used.

Rows, left to right:

1. Head, cuirass, belt/tassets, sword.
2. Pauldron, upper arm, forearm, gauntlet.
3. Thigh, greave, sabaton, crimson cape.
4. Tabard, fur collar, belt pouch, dragon amulet.

The exact source rectangles, attachment pivots, limb lengths and cloth deformation are defined in `scripts/Flamewarden.gd`. The PNG remains a single lossless asset; parts are sampled directly, with no runtime image segmentation. Rear limbs use the same artwork with cooler shading. Rendering uses the existing compatibility renderer and does not require Skeleton2D, an animation middleware license or a network service.
