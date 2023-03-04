// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.17;

import {DataTypesV2} from './DataTypesV2.sol';

/**
 * @title ReserveConfiguration library
 * @author Aave
 * @notice Implements the bitmap logic to handle the reserve configuration
 */
library ReserveConfigurationV2 {
    uint256 constant LTV_MASK =                   0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000; // prettier-ignore
    uint256 constant LIQUIDATION_THRESHOLD_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFF; // prettier-ignore
    uint256 constant LIQUIDATION_BONUS_MASK =     0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFF; // prettier-ignore
    uint256 constant DECIMALS_MASK =              0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00FFFFFFFFFFFF; // prettier-ignore
    uint256 constant ACTIVE_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant FROZEN_MASK =                0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFDFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant BORROWING_MASK =             0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant STABLE_BORROWING_MASK =      0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF7FFFFFFFFFFFFFF; // prettier-ignore
    uint256 constant RESERVE_FACTOR_MASK =        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000FFFFFFFFFFFFFFFF; // prettier-ignore

    /// @dev For the LTV, the start bit is 0 (up to 15), hence no bitshifting is needed
    uint256 constant LIQUIDATION_THRESHOLD_START_BIT_POSITION = 16;
    uint256 constant LIQUIDATION_BONUS_START_BIT_POSITION = 32;
    uint256 constant RESERVE_DECIMALS_START_BIT_POSITION = 48;
    uint256 constant IS_ACTIVE_START_BIT_POSITION = 56;
    uint256 constant IS_FROZEN_START_BIT_POSITION = 57;
    uint256 constant BORROWING_ENABLED_START_BIT_POSITION = 58;
    uint256 constant STABLE_BORROWING_ENABLED_START_BIT_POSITION = 59;
    uint256 constant RESERVE_FACTOR_START_BIT_POSITION = 64;

    uint256 constant MAX_VALID_LTV = 65535;
    uint256 constant MAX_VALID_LIQUIDATION_THRESHOLD = 65535;
    uint256 constant MAX_VALID_LIQUIDATION_BONUS = 65535;
    uint256 constant MAX_VALID_DECIMALS = 255;
    uint256 constant MAX_VALID_RESERVE_FACTOR = 65535;

    /**
     * @dev Gets the Loan to Value of the reserve
     * @param self The reserve configuration
     * @return The loan to value
     **/
    function getLtv(DataTypesV2.ReserveConfigurationMap storage self) internal view returns (uint256) {
        return self.data & ~LTV_MASK;
    }

    /**
     * @dev Gets the liquidation threshold of the reserve
     * @param self The reserve configuration
     * @return The liquidation threshold
     **/
    function getLiquidationThreshold(DataTypesV2.ReserveConfigurationMap storage self) internal view returns (uint256) {
        return (self.data & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION;
    }

    /**
     * @dev Gets the liquidation bonus of the reserve
     * @param self The reserve configuration
     * @return The liquidation bonus
     **/
    function getLiquidationBonus(DataTypesV2.ReserveConfigurationMap storage self) internal view returns (uint256) {
        return (self.data & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION;
    }

    /**
     * @dev Gets the decimals of the underlying asset of the reserve
     * @param self The reserve configuration
     * @return The decimals of the asset
     **/
    function getDecimals(DataTypesV2.ReserveConfigurationMap storage self) internal view returns (uint256) {
        return (self.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION;
    }

    /**
     * @dev Gets the active state of the reserve
     * @param self The reserve configuration
     * @return The active state
     **/
    function getActive(DataTypesV2.ReserveConfigurationMap storage self) internal view returns (bool) {
        return (self.data & ~ACTIVE_MASK) != 0;
    }

    /**
     * @dev Gets the frozen state of the reserve
     * @param self The reserve configuration
     * @return The frozen state
     **/
    function getFrozen(DataTypesV2.ReserveConfigurationMap storage self) internal view returns (bool) {
        return (self.data & ~FROZEN_MASK) != 0;
    }

    /**
     * @dev Gets the borrowing state of the reserve
     * @param self The reserve configuration
     * @return The borrowing state
     **/
    function getBorrowingEnabled(DataTypesV2.ReserveConfigurationMap storage self) internal view returns (bool) {
        return (self.data & ~BORROWING_MASK) != 0;
    }

    /**
     * @dev Gets the stable rate borrowing state of the reserve
     * @param self The reserve configuration
     * @return The stable rate borrowing state
     **/
    function getStableRateBorrowingEnabled(DataTypesV2.ReserveConfigurationMap storage self)
        internal
        view
        returns (bool)
    {
        return (self.data & ~STABLE_BORROWING_MASK) != 0;
    }

    /**
     * @dev Gets the reserve factor of the reserve
     * @param self The reserve configuration
     * @return The reserve factor
     **/
    function getReserveFactor(DataTypesV2.ReserveConfigurationMap storage self) internal view returns (uint256) {
        return (self.data & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION;
    }

    /**
     * @dev Gets the configuration flags of the reserve
     * @param self The reserve configuration
     * @return The state flags representing active, frozen, borrowing enabled, stableRateBorrowing enabled
     **/
    function getFlags(DataTypesV2.ReserveConfigurationMap storage self)
        internal
        view
        returns (
            bool,
            bool,
            bool,
            bool
        )
    {
        uint256 dataLocal = self.data;

        return (
            (dataLocal & ~ACTIVE_MASK) != 0,
            (dataLocal & ~FROZEN_MASK) != 0,
            (dataLocal & ~BORROWING_MASK) != 0,
            (dataLocal & ~STABLE_BORROWING_MASK) != 0
        );
    }

    /**
     * @dev Gets the configuration paramters of the reserve
     * @param self The reserve configuration
     * @return The state params representing ltv, liquidation threshold, liquidation bonus, the reserve decimals
     **/
    function getParams(DataTypesV2.ReserveConfigurationMap storage self)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256 dataLocal = self.data;

        return (
            dataLocal & ~LTV_MASK,
            (dataLocal & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (dataLocal & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
            (dataLocal & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
            (dataLocal & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION
        );
    }

    /**
     * @dev Gets the configuration paramters of the reserve from a memory object
     * @param self The reserve configuration
     * @return The state params representing ltv, liquidation threshold, liquidation bonus, the reserve decimals
     **/
    function getParamsMemory(DataTypesV2.ReserveConfigurationMap memory self)
        internal
        pure
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            self.data & ~LTV_MASK,
            (self.data & ~LIQUIDATION_THRESHOLD_MASK) >> LIQUIDATION_THRESHOLD_START_BIT_POSITION,
            (self.data & ~LIQUIDATION_BONUS_MASK) >> LIQUIDATION_BONUS_START_BIT_POSITION,
            (self.data & ~DECIMALS_MASK) >> RESERVE_DECIMALS_START_BIT_POSITION,
            (self.data & ~RESERVE_FACTOR_MASK) >> RESERVE_FACTOR_START_BIT_POSITION
        );
    }

    /**
     * @dev Gets the configuration flags of the reserve from a memory object
     * @param self The reserve configuration
     * @return The state flags representing active, frozen, borrowing enabled, stableRateBorrowing enabled
     **/
    function getFlagsMemory(DataTypesV2.ReserveConfigurationMap memory self)
        internal
        pure
        returns (
            bool,
            bool,
            bool,
            bool
        )
    {
        return (
            (self.data & ~ACTIVE_MASK) != 0,
            (self.data & ~FROZEN_MASK) != 0,
            (self.data & ~BORROWING_MASK) != 0,
            (self.data & ~STABLE_BORROWING_MASK) != 0
        );
    }
}
