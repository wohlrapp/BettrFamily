import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var familyCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo area
                VStack(spacing: 8) {
                    Image(systemName: "house.and.flag.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    Text("BettrFamily")
                        .font(.largeTitle.bold())
                    Text("Transparenz fuer die Familie")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Form
                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("Name", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }

                    TextField("E-Mail", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Passwort", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)

                    if isSignUp {
                        TextField("Family-Code (leer = neue Familie)", text: $familyCode)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await authenticate() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(isSignUp ? "Registrieren" : "Anmelden")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || email.isEmpty || password.isEmpty || (isSignUp && name.isEmpty))

                    Button(isSignUp ? "Bereits registriert? Anmelden" : "Noch kein Account? Registrieren") {
                        isSignUp.toggle()
                        errorMessage = nil
                    }
                    .font(.footnote)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
        }
    }

    private func authenticate() async {
        isLoading = true
        errorMessage = nil

        do {
            if isSignUp {
                try await authService.signUp(
                    email: email,
                    password: password,
                    name: name,
                    familyCode: familyCode
                )
            } else {
                try await authService.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
