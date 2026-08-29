package com.omninest.common.sync;

import java.util.UUID;

/**
 * 业务模块记录用户同步事件的公共接口。
 *
 * @author OmniNest
 */
public interface UserSyncEventRecorder {

    /**
     * 在当前业务事务中记录同步事件。
     *
     * @param command 同步事件命令
     * @return 事件标识
     */
    UUID record(SyncEventCommand command);
}
