import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public struct AuthTransferExportedToken {
    public let value: Data
    public let validUntil: Int32
}

public enum ExportAuthTransferTokenError {
    case generic
    case limitExceeded
}

public enum ExportAuthTransferTokenResult {
    case displayToken(AuthTransferExportedToken)
    case changeAccountAndRetry(UnauthorizedAccount)
    case loggedIn
    case passwordRequested(UnauthorizedAccount)
}

func _internal_exportAuthTransferToken(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, otherAccountUserIds: [PeerId.Id], syncContacts: Bool) -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> {
    return account.network.request(Api.functions.auth.exportLoginToken(apiId: account.networkArguments.apiId, apiHash: account.networkArguments.apiHash, exceptIds: otherAccountUserIds.map({ $0._internalGetInt64Value() })))
    |> map(Optional.init)
    |> `catch` { error -> Signal<Api.auth.LoginToken?, ExportAuthTransferTokenError> in
        if error.errorDescription == "SESSION_PASSWORD_NEEDED" {
            return account.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
            |> mapError { error -> ExportAuthTransferTokenError in
                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                    return .limitExceeded
                } else {
                    return .generic
                }
            }
            |> mapToSignal { result -> Signal<Api.auth.LoginToken?, ExportAuthTransferTokenError> in
                switch result {
                case let .password(passwordData):
                    let hint = passwordData.hint
                    return account.postbox.transaction { transaction -> Api.auth.LoginToken? in
                        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .passwordEntry(hint: hint ?? "", number: nil, code: nil, suggestReset: false, syncContacts: syncContacts)))
                        return nil
                    }
                    |> castError(ExportAuthTransferTokenError.self)
                }
            }
        } else {
            return .fail(.generic)
        }
    }
    |> mapToSignal { result -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
        guard let result = result else {
            return .single(.passwordRequested(account))
        }
        switch result {
        case let .loginToken(loginTokenData):
            let (expires, token) = (loginTokenData.expires, loginTokenData.token)
            return .single(.displayToken(AuthTransferExportedToken(value: token.makeData(), validUntil: expires)))
        case let .loginTokenMigrateTo(loginTokenMigrateToData):
            let (dcId, token) = (loginTokenMigrateToData.dcId, loginTokenMigrateToData.token)
            let updatedAccount = account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: dcId)
            return updatedAccount
            |> castError(ExportAuthTransferTokenError.self)
            |> mapToSignal { updatedAccount -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
                return updatedAccount.network.request(Api.functions.auth.importLoginToken(token: token))
                |> map(Optional.init)
                |> `catch` { error -> Signal<Api.auth.LoginToken?, ExportAuthTransferTokenError> in
                    if error.errorDescription == "SESSION_PASSWORD_NEEDED" {
                        return updatedAccount.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
                        |> mapError { error -> ExportAuthTransferTokenError in
                            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                                return .limitExceeded
                            } else {
                                return .generic
                            }
                        }
                        |> mapToSignal { result -> Signal<Api.auth.LoginToken?, ExportAuthTransferTokenError> in
                            switch result {
                            case let .password(passwordData):
                                let hint = passwordData.hint
                                return updatedAccount.postbox.transaction { transaction -> Api.auth.LoginToken? in
                                    transaction.setState(UnauthorizedAccountState(isTestingEnvironment: updatedAccount.testingEnvironment, masterDatacenterId: updatedAccount.masterDatacenterId, contents: .passwordEntry(hint: hint ?? "", number: nil, code: nil, suggestReset: false, syncContacts: syncContacts)))
                                    return nil
                                }
                                |> castError(ExportAuthTransferTokenError.self)
                            }
                        }
                    } else {
                        return .fail(.generic)
                    }
                }
                |> mapToSignal { result -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
                    guard let result = result else {
                        return .single(.passwordRequested(updatedAccount))
                    }
                    switch result {
                    case let .loginTokenSuccess(loginTokenSuccessData):
                        let authorization = loginTokenSuccessData.authorization
                        switch authorization {
                        case let .authorization(authorizationData):
                            let (futureAuthToken, apiUser) = (authorizationData.futureAuthToken, authorizationData.user)
                            if let futureAuthToken = futureAuthToken {
                                storeFutureLoginToken(accountManager: accountManager, token: futureAuthToken.makeData())
                            }

                            return updatedAccount.postbox.transaction { transaction -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
                                let user = TelegramUser(user: apiUser)
                                let state = AuthorizedAccountState(isTestingEnvironment: updatedAccount.testingEnvironment, masterDatacenterId: updatedAccount.masterDatacenterId, peerId: user.id, state: nil, invalidatedChannels: [])
                                initializedAppSettingsAfterLogin(transaction: transaction, appVersion: updatedAccount.networkArguments.appVersion, syncContacts: syncContacts)
                                transaction.setState(state)
                                return accountManager.transaction { transaction -> ExportAuthTransferTokenResult in
                                    switchToAuthorizedAccount(transaction: transaction, account: updatedAccount, isSupportUser: false)
                                    return .loggedIn
                                }
                                |> castError(ExportAuthTransferTokenError.self)
                            }
                            |> castError(ExportAuthTransferTokenError.self)
                            |> switchToLatest
                        default:
                            return .fail(.generic)
                        }
                    default:
                        return .single(.changeAccountAndRetry(updatedAccount))
                    }
                }
            }
        case let .loginTokenSuccess(loginTokenSuccessData):
            let authorization = loginTokenSuccessData.authorization
            switch authorization {
            case let .authorization(authorizationData):
                let (futureAuthToken, apiUser) = (authorizationData.futureAuthToken, authorizationData.user)
                if let futureAuthToken = futureAuthToken {
                    storeFutureLoginToken(accountManager: accountManager, token: futureAuthToken.makeData())
                }

                return account.postbox.transaction { transaction -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> in
                    let user = TelegramUser(user: apiUser)
                    let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil, invalidatedChannels: [])
                    initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                    transaction.setState(state)
                    return accountManager.transaction { transaction -> ExportAuthTransferTokenResult in
                        switchToAuthorizedAccount(transaction: transaction, account: account, isSupportUser: false)
                        return .loggedIn
                    }
                    |> castError(ExportAuthTransferTokenError.self)
                }
                |> castError(ExportAuthTransferTokenError.self)
                |> switchToLatest
            case .authorizationSignUpRequired:
                return .fail(.generic)
            }
        }
    }
}

public enum ImportAuthTransferTokenError {
    case generic
    case invalid
    case expired
    case alreadyAccepted
    case limitExceeded
}

// Telegram Plus: log THIS device in with a login token produced elsewhere
// (auth.importLoginToken), instead of confirming someone else's login
// (auth.acceptLoginToken). The token is the one carried by a "tg://login?token=..."
// code, e.g. one shown by another client and captured as an image. No SMS code and
// no signup captcha are involved: the existing session that produced the code is
// the proof. Reaching `.loggedIn` switches the account manager to an authorised
// account, exactly like the export path above does when its token is confirmed.
func _internal_importAuthTransferToken(accountManager: AccountManager<TelegramAccountManagerTypes>, account: UnauthorizedAccount, token: Data, syncContacts: Bool) -> Signal<ExportAuthTransferTokenResult, ImportAuthTransferTokenError> {
    return account.network.request(Api.functions.auth.importLoginToken(token: Buffer(data: token)))
    |> map(Optional.init)
    |> `catch` { error -> Signal<Api.auth.LoginToken?, ImportAuthTransferTokenError> in
        switch error.errorDescription {
        case "AUTH_TOKEN_INVALID":
            return .fail(.invalid)
        case "AUTH_TOKEN_EXPIRED":
            return .fail(.expired)
        case "AUTH_TOKEN_ALREADY_ACCEPTED":
            return .fail(.alreadyAccepted)
        case "SESSION_PASSWORD_NEEDED":
            return account.network.request(Api.functions.account.getPassword(), automaticFloodWait: false)
            |> mapError { error -> ImportAuthTransferTokenError in
                if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                    return .limitExceeded
                } else {
                    return .generic
                }
            }
            |> mapToSignal { result -> Signal<Api.auth.LoginToken?, ImportAuthTransferTokenError> in
                switch result {
                case let .password(passwordData):
                    let hint = passwordData.hint
                    return account.postbox.transaction { transaction -> Api.auth.LoginToken? in
                        transaction.setState(UnauthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, contents: .passwordEntry(hint: hint ?? "", number: nil, code: nil, suggestReset: false, syncContacts: syncContacts)))
                        return nil
                    }
                    |> castError(ImportAuthTransferTokenError.self)
                }
            }
        default:
            return .fail(.generic)
        }
    }
    |> mapToSignal { result -> Signal<ExportAuthTransferTokenResult, ImportAuthTransferTokenError> in
        guard let result = result else {
            return .single(.passwordRequested(account))
        }
        switch result {
        case let .loginTokenSuccess(loginTokenSuccessData):
            let authorization = loginTokenSuccessData.authorization
            switch authorization {
            case let .authorization(authorizationData):
                let (futureAuthToken, apiUser) = (authorizationData.futureAuthToken, authorizationData.user)
                if let futureAuthToken = futureAuthToken {
                    storeFutureLoginToken(accountManager: accountManager, token: futureAuthToken.makeData())
                }

                return account.postbox.transaction { transaction -> Signal<ExportAuthTransferTokenResult, ImportAuthTransferTokenError> in
                    let user = TelegramUser(user: apiUser)
                    let state = AuthorizedAccountState(isTestingEnvironment: account.testingEnvironment, masterDatacenterId: account.masterDatacenterId, peerId: user.id, state: nil, invalidatedChannels: [])
                    initializedAppSettingsAfterLogin(transaction: transaction, appVersion: account.networkArguments.appVersion, syncContacts: syncContacts)
                    transaction.setState(state)
                    return accountManager.transaction { transaction -> ExportAuthTransferTokenResult in
                        switchToAuthorizedAccount(transaction: transaction, account: account, isSupportUser: false)
                        return .loggedIn
                    }
                    |> castError(ImportAuthTransferTokenError.self)
                }
                |> castError(ImportAuthTransferTokenError.self)
                |> switchToLatest
            case .authorizationSignUpRequired:
                return .fail(.invalid)
            }
        case let .loginTokenMigrateTo(loginTokenMigrateToData):
            let updatedAccount = account.changedMasterDatacenterId(accountManager: accountManager, masterDatacenterId: loginTokenMigrateToData.dcId)
            return updatedAccount
            |> castError(ImportAuthTransferTokenError.self)
            |> mapToSignal { updatedAccount -> Signal<ExportAuthTransferTokenResult, ImportAuthTransferTokenError> in
                return _internal_importAuthTransferToken(accountManager: accountManager, account: updatedAccount, token: loginTokenMigrateToData.token.makeData(), syncContacts: syncContacts)
            }
        case .loginToken:
            // Importing never yields a displayable token of our own; treat as failure
            // rather than pretending the login succeeded.
            return .fail(.generic)
        }
    }
}

public enum ApproveAuthTransferTokenError {
    case generic
    case invalid
    case expired
    case alreadyAccepted
}

public func approveAuthTransferToken(account: Account, token: Data, activeSessionsContext: ActiveSessionsContext) -> Signal<RecentAccountSession, ApproveAuthTransferTokenError> {
    return account.network.request(Api.functions.auth.acceptLoginToken(token: Buffer(data: token)))
    |> mapError { error -> ApproveAuthTransferTokenError in
        switch error.errorDescription {
        case "AUTH_TOKEN_INVALID":
            return .invalid
        case "AUTH_TOKEN_EXPIRED":
            return .expired
        case "AUTH_TOKEN_ALREADY_ACCEPTED":
            return .alreadyAccepted
        default:
            return .generic
        }
    }
    |> mapToSignal { authorization -> Signal<RecentAccountSession, ApproveAuthTransferTokenError> in
        let session = RecentAccountSession(apiAuthorization: authorization)
        activeSessionsContext.addSession(session)
        return .single(session)
    }
}
