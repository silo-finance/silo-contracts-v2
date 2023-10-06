import { Signer } from "ethers";
import { Provider } from "@ethersproject/providers";
import type { WETH, WETHInterface } from "../WETH";
export declare class WETH__factory {
    static readonly abi: {
        constant: boolean;
        inputs: {
            name: string;
            type: string;
        }[];
        name: string;
        outputs: never[];
        payable: boolean;
        stateMutability: string;
        type: string;
    }[];
    static createInterface(): WETHInterface;
    static connect(address: string, signerOrProvider: Signer | Provider): WETH;
}
