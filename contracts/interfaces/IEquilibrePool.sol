// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

import './pool/IEquilibrePoolImmutables.sol';
import './pool/IEquilibrePoolState.sol';
import './pool/IEquilibrePoolDerivedState.sol';
import './pool/IEquilibrePoolActions.sol';
import './pool/IEquilibrePoolOwnerActions.sol';
import './pool/IEquilibrePoolEvents.sol';

/// @title The interface for a Equilibre V3 Pool
/// @notice A Equilibre pool facilitates swapping and automated market making between any two assets that strictly conform
/// to the ERC20 specification
/// @dev The pool interface is broken up into many smaller pieces
interface IEquilibrePool is
    IEquilibrePoolImmutables,
    IEquilibrePoolState,
    IEquilibrePoolDerivedState,
    IEquilibrePoolActions,
    IEquilibrePoolOwnerActions,
    IEquilibrePoolEvents
{

}
