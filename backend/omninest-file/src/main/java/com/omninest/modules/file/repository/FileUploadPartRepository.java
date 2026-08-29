package com.omninest.modules.file.repository;

import com.omninest.modules.file.domain.FileUploadPart;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface FileUploadPartRepository extends JpaRepository<FileUploadPart, UUID> {
    List<FileUploadPart> findByUploadSessionIdOrderByPartNumber(UUID uploadSessionId);

    Optional<FileUploadPart> findByUploadSessionIdAndPartNumber(UUID uploadSessionId, int partNumber);

    void deleteByUploadSessionId(UUID uploadSessionId);
}
