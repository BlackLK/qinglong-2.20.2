/**
 * IP 结果
 */
export interface Ipv4ToRegionRes {
    /** 城市 id */
    city: number;
    /** 区域字符串 */
    region: string;
}
/**
 * IP 解析结果
 */
export interface Ipv4ToRegionResult {
    /** 城市 id */
    id: number;
    /** 国家 */
    country: string;
    /** 区域 */
    region: string;
    /** 省份 */
    province: string;
    /** 城市 */
    city: string;
    /** ISP 供应商 */
    isp: string;
}
/**
 * IP v4 解析
 */
export default class Ipv4ToRegion {
    /**  数据库文件位置 */
    private dbFilePath;
    private superBlock;
    private indexBlockLength;
    private data;
    private firstIndexPtr;
    private lastIndexPtr;
    private totalBlocks;
    constructor(dbPath?: string);
    parseResult(res: Ipv4ToRegionRes | null): {
        id: number;
        country: string;
        region: string;
        province: string;
        city: string;
        isp: string;
    } | null;
    searchLong(ip: number): Ipv4ToRegionRes | null;
    search(ipaddr: string): Ipv4ToRegionResult;
    search(ipaddr: string, parse: boolean): Ipv4ToRegionRes;
}
