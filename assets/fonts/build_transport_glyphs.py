#!/usr/bin/env python3
"""Builds TransportGlyphs.ttf: transport-mode icons Material Icons lacks.

Run: python3 assets/fonts/build_transport_glyphs.py assets/fonts/TransportGlyphs.ttf

The four glyphs are drawn from freely-licensed source icons (see
TransportGlyphs-ATTRIBUTION.txt), each normalised into a 1000x1000 box with Y
pointing DOWN, then flipped to font coordinates (Y up, baseline at 0) so it
fills the em square like a Material icon. They map to codepoints 0xE800..0xE803
(see kTransportModeIcons in lib/features/itinerary/widgets/transport_mode.dart).

Sources:
  horse     - Material Design Icons "horse-human" (Apache-2.0)
  gondola   - Temaki "gondola_lift" (CC0)
  chairlift - Temaki "chairlift"    (CC0)
  tbar      - Temaki "t_bar_lift"   (CC0)
"""
import sys
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path

EM = 1000

HORSE = (
    'M416 143C416 108 444 80 479 80C514 80 542 108 542 143C542 178 514 206 479 206C444 206 416 178 416 143M920 332V479L877 494C870 545 826 584 773 584H770C764 613 750 638 731 659V920H626V710C623 710 619 710 616 710C607 710 598 709 590 707L403 676L356 761L388 920H281L248 762C247 750 248 737 255 726L298 650C257 627 228 584 227 534C226 540 225 550 226 563C227 581 232 609 229 639C227 669 213 700 196 721C178 741 158 756 137 767L108 737C116 717 124 700 125 683C128 668 125 655 120 644L98 597C89 575 78 544 80 508C82 472 101 425 139 400C176 374 217 370 250 377C271 382 293 392 311 406C327 399 345 395 364 395H374V337C374 295 403 256 444 249C497 241 542 281 542 332V395H605V374C605 281 680 206 773 206H920L883 262C905 277 920 303 920 332M836 466 792 397C787 388 773 392 773 402V542C808 542 836 514 836 479V466Z'
)
GONDOLA = (
    'M472 241C455 231 444 213 444 192V185L167 220C152 222 138 211 136 196C134 180 145 166 161 164L445 129C448 101 471 80 500 80C524 80 544 95 552 115L833 80C848 78 862 89 864 105C866 120 855 134 839 136L556 171V192C556 213 545 231 528 241V360H649C676 360 699 380 704 406L750 657C751 664 751 672 750 679L705 876C700 902 677 920 651 920H349C323 920 300 902 295 876L250 679C249 672 249 664 250 657L296 406C301 380 324 360 351 360H472V241ZM359 416C352 416 347 421 345 427L307 623C307 624 307 625 307 626C307 634 314 640 321 640H458C466 640 472 634 472 626V430C472 422 466 416 458 416H359ZM641 416H542C534 416 528 422 528 430V626C528 634 534 640 542 640H679C686 640 693 634 693 626C693 625 693 624 693 623L655 427C653 421 648 416 641 416Z'
)
CHAIRLIFT = (
    'M808 713C840 702 858 668 847 636L824 644C830 663 819 684 800 690L187 897L195 920L808 713H808ZM244 355C277 345 296 310 287 277C277 243 241 224 208 234C174 243 154 279 164 312C174 345 210 365 243 355H244ZM217 442C184 379 280 328 316 389L385 519L516 482C538 476 568 500 568 527L569 713C569 759 500 760 500 713C500 670 499 578 499 578L361 619C331 627 306 612 295 590L217 442L217 442ZM430 472V80H395V479L430 472ZM154 527C135 490 184 466 203 503L262 618C275 642 301 658 330 658C339 658 347 656 356 654L430 633C470 621 486 673 446 684L367 707C355 711 342 713 329 713C278 713 235 684 213 643L154 527L154 527Z'
)
TBAR = (
    'M470 770V372C452 362 440 342 440 320V193L144 230C127 232 112 221 110 204C108 188 120 173 136 170L441 132C444 103 469 80 500 80C525 80 547 96 556 118L856 80C873 78 888 90 890 107C892 123 880 138 864 140L560 178V320C560 342 548 362 530 372V770H802C815 770 827 779 831 792C835 807 826 824 810 829L500 920L190 829C177 825 168 813 168 800C168 783 182 770 198 770H470Z'
)

GLYPHS = {"horse": HORSE, "gondola": GONDOLA, "chairlift": CHAIRLIFT, "tbar": TBAR}
CODEPOINTS = {"horse": 0xE800, "gondola": 0xE801, "chairlift": 0xE802, "tbar": 0xE803}


def build_glyph(d):
    ttpen = TTGlyphPen(None)
    cu2qu = Cu2QuPen(ttpen, max_err=1.0, reverse_direction=False)
    parse_path(d, TransformPen(cu2qu, (1, 0, 0, -1, 0, EM)))  # flip Y
    return ttpen.glyph()


def main(out_path):
    order = [".notdef", "horse", "gondola", "chairlift", "tbar"]
    fb = FontBuilder(EM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({CODEPOINTS[n]: n for n in GLYPHS})
    glyphs = {".notdef": TTGlyphPen(None).glyph()}
    for name, d in GLYPHS.items():
        glyphs[name] = build_glyph(d)
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({n: (EM, 0) for n in order})
    fb.setupHorizontalHeader(ascent=EM, descent=0)
    fb.setupNameTable(
        {
            "familyName": "TransportGlyphs",
            "styleName": "Regular",
            "psName": "TransportGlyphs-Regular",
        }
    )
    fb.setupOS2(sTypoAscender=EM, sTypoDescender=0, usWinAscent=EM, usWinDescent=0)
    fb.setupPost(isFixedPitch=1)
    fb.save(out_path)
    print("wrote", out_path)


if __name__ == "__main__":
    main(sys.argv[1])
