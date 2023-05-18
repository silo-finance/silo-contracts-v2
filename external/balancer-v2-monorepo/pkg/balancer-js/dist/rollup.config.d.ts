declare const _default: ({
    input: string;
    output: ({
        name: string;
        file: any;
        format: string;
        sourcemap: boolean;
    } | {
        file: any;
        format: string;
        sourcemap: boolean;
        name?: undefined;
    })[];
    plugins: import("rollup").Plugin[];
    external: string[];
} | {
    input: string;
    output: {
        file: string;
        format: string;
    }[];
    plugins: import("rollup").Plugin[];
    external?: undefined;
})[];
export default _default;
