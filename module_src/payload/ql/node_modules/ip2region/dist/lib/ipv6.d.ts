import Ipv4ToRegion, { Ipv4ToRegionRes, Ipv4ToRegionResult } from "./ipv4";
/**
 * IP 结果
 */
export interface Ipv6ToRegionRes {
    /** 区域字符串 */
    cArea: string;
    /** 运营商 */
    aArea: string;
}
/**
 * IP 解析结果
 */
export interface Ipv6ToRegionResult {
    /** 国家 */
    country: string;
    /** 省份 */
    province: string;
    /** 城市 */
    city: string;
    /** ISP 供应商 */
    isp: string;
    /** 原始数据 */
    data: string;
}
export default class Ipv6ToRegion {
    /**  数据库文件位置 */
    private dbFilePath;
    private data;
    private name;
    private offlen;
    private record;
    private indexStart;
    private ipv4?;
    constructor(dbPath?: string);
    setIpv4Ins(ins: Ipv4ToRegion): void;
    private searchIpv4;
    /**
     * 读取 Long 数据
     * @param offset 偏移量
     */
    private readLongData;
    /**
     * 使用二分法查找网络字节编码的IP地址的索引记录
     * @param ip IP地址
     * @param l 左边界
     * @param r 右边界
     */
    private find;
    /**
     * 读取字符串信息
     * @param offset 偏移量
     */
    private getString;
    /**
     * 读取区域信息字符串
     * @param offset 偏移量
     */
    private getAreaAddr;
    /**
     * 获取地址信息
     * @param offset 偏移量
     */
    private getAddr;
    private parseResult;
    private getIpAddrLong;
    searchLong(ip6: bigint): Ipv4ToRegionRes | Ipv6ToRegionRes | null;
    search(ipaddr: string, parse?: boolean): Ipv4ToRegionRes | Ipv4ToRegionResult | Ipv6ToRegionRes | Ipv6ToRegionResult | null;
}
