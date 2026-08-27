import { Ipv4ToRegionResult, Ipv4ToRegionRes } from "./ipv4";
import { Ipv6ToRegionResult, Ipv6ToRegionRes } from "./ipv6";
/** IP2Region 配置 */
export interface IP2RegionOpts {
    /** ipv4 数据库地址 */
    ipv4db?: string;
    /** ipv6 数据库地址 */
    ipv6db?: string;
    /** 关闭 ipv6 */
    disableIpv6?: boolean;
}
export interface IP2RegionResult {
    /** 国家 */
    country: string;
    /** 省份 */
    province: string;
    /** 城市 */
    city: string;
    /** ISP 供应商 */
    isp: string;
}
export default class IP2Region {
    private ipv4;
    private ipv6;
    constructor(opts?: IP2RegionOpts);
    /**
     * 原始搜索
     * @param ipaddr IP 地址
     */
    searchRaw(ipaddr: string): Ipv6ToRegionResult | Ipv4ToRegionResult | null;
    /**
     * 原始搜索
     * @param ipaddr IP 地址
     * @param parse 是否解析
     */
    searchRaw(ipaddr: string, parse: boolean): Ipv4ToRegionRes | Ipv6ToRegionRes | null;
    /**
     * 搜索
     * @param ipaddr IP 地址
     */
    search(ipaddr: string): IP2RegionResult | null;
}
