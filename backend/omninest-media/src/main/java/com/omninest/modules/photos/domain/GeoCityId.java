package com.omninest.modules.photos.domain;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

/**
 * GeoCity 复合主键：数据集 ID + GeoNames 城市 ID。
 *
 * <p>同一城市可存在于不同数据集版本中，靠 datasetId 区分。</p>
 *
 * @author OmniNest
 */
public class GeoCityId implements Serializable {

    private UUID datasetId;

    private Long geonameId;

    public GeoCityId() {
    }

    public GeoCityId(UUID datasetId, Long geonameId) {
        this.datasetId = datasetId;
        this.geonameId = geonameId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) {
            return true;
        }
        if (!(o instanceof GeoCityId other)) {
            return false;
        }
        return Objects.equals(datasetId, other.datasetId)
                && Objects.equals(geonameId, other.geonameId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(datasetId, geonameId);
    }
}
