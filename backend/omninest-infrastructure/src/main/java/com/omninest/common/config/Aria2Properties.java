package com.omninest.common.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "omninest.aria2")
public class Aria2Properties {
    private String rpcUrl = "http://localhost:6800/jsonrpc";
    private String rpcSecret = "";
    private String downloadRoot = System.getProperty("user.home") + "/.omninest/aria2";
    private int pollIntervalSeconds = 5;
    private int rpcTimeoutSeconds = 15;
    private long idleTimeoutMinutes = 30;

    public String getRpcUrl() {
        return rpcUrl;
    }

    public void setRpcUrl(String rpcUrl) {
        this.rpcUrl = rpcUrl;
    }

    public String getRpcSecret() {
        return rpcSecret;
    }

    public void setRpcSecret(String rpcSecret) {
        this.rpcSecret = rpcSecret;
    }

    public String getDownloadRoot() {
        return downloadRoot;
    }

    public void setDownloadRoot(String downloadRoot) {
        this.downloadRoot = downloadRoot;
    }

    public int getPollIntervalSeconds() {
        return pollIntervalSeconds;
    }

    public void setPollIntervalSeconds(int pollIntervalSeconds) {
        this.pollIntervalSeconds = pollIntervalSeconds;
    }

    public int getRpcTimeoutSeconds() {
        return rpcTimeoutSeconds;
    }

    public void setRpcTimeoutSeconds(int rpcTimeoutSeconds) {
        this.rpcTimeoutSeconds = rpcTimeoutSeconds;
    }

    public long getIdleTimeoutMinutes() {
        return idleTimeoutMinutes;
    }

    public void setIdleTimeoutMinutes(long idleTimeoutMinutes) {
        this.idleTimeoutMinutes = idleTimeoutMinutes;
    }
}
