package com.omninest.modules.reader.service;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

/**
 * 漫画分卷命名解析器测试。
 *
 * @author OmniNest
 */
class ComicVolumeParserTest {

    @Test
    void parsesEpisodesRange() {
        ComicVolumeParser.PartInfo part = ComicVolumeParser.parse("[Kmoe][紹宋]話001-010.epub");
        assertThat(part.matched()).isTrue();
        assertThat(part.partKind()).isEqualTo("EPISODE");
        assertThat(part.partNo()).isEqualTo(1);
        assertThat(part.rangeEnd()).isEqualTo(10);
    }

    @Test
    void parsesVolumePrefix() {
        ComicVolumeParser.PartInfo part = ComicVolumeParser.parse("[Kmoe][躲在超市後門抽煙的兩人]卷01.epub");
        assertThat(part.matched()).isTrue();
        assertThat(part.partKind()).isEqualTo("VOL");
        assertThat(part.partNo()).isEqualTo(1);
    }

    @Test
    void parsesTraditionalVolumeKanj() {
        ComicVolumeParser.PartInfo part = ComicVolumeParser.parse("[Kmoe][葬送的芙莉蓮]巻01.epub");
        assertThat(part.matched()).isTrue();
        assertThat(part.partKind()).isEqualTo("VOL");
        assertThat(part.partNo()).isEqualTo(1);
    }

    @Test
    void parsesChineseNumberVolume() {
        ComicVolumeParser.PartInfo part = ComicVolumeParser.parse("某漫画 第三卷.epub");
        assertThat(part.matched()).isTrue();
        assertThat(part.partKind()).isEqualTo("VOL");
        assertThat(part.partNo()).isEqualTo(3);
    }

    @Test
    void parsesBookChapter() {
        ComicVolumeParser.PartInfo part = ComicVolumeParser.parse("某漫画 第2册.epub");
        assertThat(part.matched()).isTrue();
        assertThat(part.partKind()).isEqualTo("VOL");
        assertThat(part.partNo()).isEqualTo(2);
    }

    @Test
    void parsesEnglishVolume() {
        ComicVolumeParser.PartInfo part = ComicVolumeParser.parse("某漫画 Vol.1.epub");
        assertThat(part.matched()).isTrue();
        assertThat(part.partKind()).isEqualTo("VOL");
        assertThat(part.partNo()).isEqualTo(1);
    }

    @Test
    void parsesSeasonEpisode() {
        ComicVolumeParser.PartInfo part = ComicVolumeParser.parse("某动画 S01E02.cbz");
        assertThat(part.matched()).isTrue();
        assertThat(part.partKind()).isEqualTo("SEASON_EP");
        assertThat(part.partNo()).isEqualTo(1);
        assertThat(part.rangeEnd()).isEqualTo(2);
    }

    @Test
    void normalizesTitleStripsTagsAndPartSuffix() {
        assertThat(ComicVolumeParser.normalizeTitle("[Kmoe][紹宋]話001-010"))
                .isEqualTo("紹宋");
        assertThat(ComicVolumeParser.normalizeTitle("[Kmoe][躲在超市後門抽煙的兩人]卷01"))
                .isEqualTo("躲在超市後門抽煙的兩人");
        assertThat(ComicVolumeParser.normalizeTitle("某漫画 第1卷"))
                .isEqualTo("某漫画");
    }

    @Test
    void noPartSignalForPlainTitle() {
        assertThat(ComicVolumeParser.hasPartSignal("白夜")).isFalse();
        assertThat(ComicVolumeParser.parse("白夜").matched()).isFalse();
    }
}
