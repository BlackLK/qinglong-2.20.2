/**
 * 创建 debug
 */
export declare function createDebug(name?: string): any;
/**
 * Convert ip to long (xxx.xxx.xxx.xxx to a integer)
 *
 * @param {string} ip IP Address
 * @returns {number} long value
 */
export declare function ipv4ToLong(ip: string): number;
export declare function ipv6ToLong(ip: string): {
    ip: string;
    num: bigint;
};
