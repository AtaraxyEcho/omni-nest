package com.omninest.modules.user.domain;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.util.UUID;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "auth_permissions", schema = "omni")
@Data
@AllArgsConstructor
@NoArgsConstructor
public class AuthPermission {
    @Id
    private UUID id;

    @Column(nullable = false, length = 120, unique = true)
    private String code;

    @Column(nullable = false, length = 120)
    private String name;

    @Column(nullable = false, length = 80)
    private String module;

    @Column(length = 500)
    private String description;

    @Column(nullable = false)
    private boolean enabled = true;

    @PrePersist
    void fillId() {
        if (id == null) {
            id = UUID.randomUUID();
        }
    }
}
