package com.omninest.modules.file.service;

import java.io.IOException;
import java.io.InputStream;
import java.io.RandomAccessFile;
import java.util.function.LongConsumer;

/**
 * 提供外部导入传输使用的进度跟踪与有界读取流。
 *
 * @author OmniNest
 */
final class ExternalImportStreams {

    private ExternalImportStreams() {
    }

    static InputStream tracking(InputStream delegate, LongConsumer onProgress) {
        return new ProgressInputStream(delegate, onProgress);
    }

    static InputStream bounded(RandomAccessFile file, long limit, LongConsumer onProgress) {
        return new BoundedRandomAccessInputStream(file, limit, onProgress);
    }

    /**
     * 在读取时回调累计字节数的输入流。
     *
     * @author OmniNest
     */
    private static final class ProgressInputStream extends InputStream {
        private final InputStream delegate;
        private final LongConsumer onProgress;
        private long totalRead;

        private ProgressInputStream(InputStream delegate, LongConsumer onProgress) {
            this.delegate = delegate;
            this.onProgress = onProgress;
        }

        @Override
        public int read() throws IOException {
            int value = delegate.read();
            if (value >= 0) {
                totalRead++;
                onProgress.accept(totalRead);
            }
            return value;
        }

        @Override
        public int read(byte[] buffer, int offset, int length) throws IOException {
            int read = delegate.read(buffer, offset, length);
            if (read > 0) {
                totalRead += read;
                onProgress.accept(totalRead);
            }
            return read;
        }

        @Override
        public int available() throws IOException {
            return delegate.available();
        }

        @Override
        public void close() throws IOException {
            delegate.close();
        }
    }

    /**
     * 从随机访问文件当前位置读取固定长度内容的输入流。
     *
     * @author OmniNest
     */
    private static final class BoundedRandomAccessInputStream extends InputStream {
        private final RandomAccessFile file;
        private final long limit;
        private final LongConsumer onProgress;
        private long bytesRead;

        private BoundedRandomAccessInputStream(RandomAccessFile file, long limit, LongConsumer onProgress) {
            this.file = file;
            this.limit = limit;
            this.onProgress = onProgress;
        }

        @Override
        public int read() throws IOException {
            if (bytesRead >= limit) {
                return -1;
            }
            int value = file.read();
            if (value >= 0) {
                bytesRead++;
                onProgress.accept(bytesRead);
            }
            return value;
        }

        @Override
        public int read(byte[] buffer, int offset, int length) throws IOException {
            if (bytesRead >= limit) {
                return -1;
            }
            int allowedLength = (int) Math.min(length, limit - bytesRead);
            int read = file.read(buffer, offset, allowedLength);
            if (read > 0) {
                bytesRead += read;
                onProgress.accept(bytesRead);
            }
            return read;
        }

        @Override
        public void close() {
            // RandomAccessFile 由调用方的 try-with-resources 管理。
        }
    }
}
