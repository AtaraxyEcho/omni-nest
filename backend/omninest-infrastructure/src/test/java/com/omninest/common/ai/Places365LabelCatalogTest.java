package com.omninest.common.ai;

import org.assertj.core.api.Assertions;
import org.junit.jupiter.api.Test;

/**
 * Places365 标签目录测试。
 *
 * @author OmniNest
 */
class Places365LabelCatalogTest {

    private final Places365LabelCatalog catalog = new Places365LabelCatalog();

    @Test
    void normalizeMapsNumericIndexesAndReadablePaths() {
        Assertions.assertThat(catalog.normalize("0")).isEqualTo("Airfield");
        Assertions.assertThat(catalog.normalize("8")).isEqualTo("Apartment building / outdoor");
        Assertions.assertThat(catalog.normalize("/a/airplane_cabin")).isEqualTo("Airplane cabin");
    }

    @Test
    void normalizePreservesUnknownNumericAndReadableLabels() {
        Assertions.assertThat(catalog.normalize("9999")).isEqualTo("9999");
        Assertions.assertThat(catalog.normalize("forest trail")).isEqualTo("Forest trail");
        Assertions.assertThat(catalog.normalize(null)).isNull();
    }
}
