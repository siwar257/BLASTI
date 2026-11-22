import { useState } from 'react';
import { ActivityIndicator, Alert, ImageBackground, KeyboardAvoidingView, Platform, Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { CarFront, UserRound } from 'lucide-react-native';
import { Eyebrow, Logo } from './ui';
import { colors } from './theme';
import { useStore } from './store';

export default function AccessScreen() {
  const { signIn, signUp, connection } = useStore();
  const [role, setRole] = useState<'passenger' | 'operator'>('passenger');
  const [register, setRegister] = useState(false);
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    const cleanEmail = email.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(cleanEmail)) {
      Alert.alert('Email ghalet', 'Saisissez une adresse e-mail valide.');
      return;
    }
    if (register && (name.trim().length < 2 || name.trim().length > 80)) {
      Alert.alert('Essem ghalet', 'Le nom doit contenir entre 2 et 80 caractères.');
      return;
    }
    if (password.length < 8 || !/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
      Alert.alert('Kelmet el 3bour', 'Le mot de passe doit contenir au moins 8 caractères, une lettre et un chiffre.');
      return;
    }

    setBusy(true);
    try {
      const error = register
        ? await signUp(name, cleanEmail, password)
        : await signIn(cleanEmail, password, role);
      if (error) Alert.alert(register && error.startsWith('Siftna lik mail') ? 'Confirmation email' : register ? 'Ma najamnach na3mlou compte' : 'Ma najamnach nodkhlou', error);
    } catch (error) {
      Alert.alert('Sar mochkel', error instanceof Error ? error.message : '3awed jarreb ba3d chwaya.');
    } finally {
      setBusy(false);
    }
  };

  return <SafeAreaView style={s.safe}>
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <ScrollView contentContainerStyle={s.content} keyboardShouldPersistTaps="handled">
        <View style={s.brand}><Logo/><Text style={s.slogan}>Bla z7am, bla 7ira.</Text></View>
        <ImageBackground source={{ uri: 'https://images.unsplash.com/photo-1533105079780-92b9be482077?auto=format&fit=crop&w=1100&q=85' }} imageStyle={s.coverImage} style={s.cover}>
          <View style={s.shade}/>
          <Eyebrow light>SOUSSE · TUNISIE</Eyebrow>
          <Text style={s.hero}>Mchwarik yebda{'\n'}9bal ma tokhrej.</Text>
          <Text style={s.heroSub}>O7jez blastek, w a3ref wa9tech tal9a l louage.</Text>
        </ImageBackground>
        <View style={s.form}>
          <Text style={s.formTitle}>{register ? 'A3mel compte jdid' : 'Dkhol l compte mte3ek'}</Text>
          <Text style={s.formSub}>Enti chkun?</Text>
          <View style={s.roles}>
            <Pressable onPress={() => { setRole('passenger'); setRegister(false); }} style={[s.roleCard, role === 'passenger' && s.roleActive]}>
              <UserRound size={19} color={role === 'passenger' ? colors.navy : '#8492a0'}/>
              <Text style={[s.roleText, role === 'passenger' && s.roleTextActive]}>Mousfer</Text>
            </Pressable>
            <Pressable onPress={() => { setRole('operator'); setRegister(false); }} style={[s.roleCard, role === 'operator' && s.roleActive]}>
              <CarFront size={20} color={role === 'operator' ? colors.navy : '#8492a0'}/>
              <Text style={[s.roleText, role === 'operator' && s.roleTextActive]}>Chauffeur</Text>
            </Pressable>
          </View>
          {register && <TextInput value={name} onChangeText={setName} placeholder="Essem w la9ab" autoCapitalize="words" maxLength={80} style={s.input}/>}
          <TextInput value={email} onChangeText={setEmail} placeholder="Email" keyboardType="email-address" autoCapitalize="none" autoComplete="email" maxLength={254} style={s.input}/>
          <TextInput value={password} onChangeText={setPassword} placeholder="Kelmet el 3bour" secureTextEntry autoComplete={register ? 'new-password' : 'current-password'} maxLength={128} style={s.input}/>
          <Pressable disabled={busy} style={[s.submit, busy && { opacity: .7 }]} onPress={() => void submit()}>
            {busy ? <ActivityIndicator color="#fff"/> : <Text style={s.submitText}>{register ? 'A3mel compte' : 'Dkhol'}</Text>}
          </Pressable>
          {role === 'passenger' && <Pressable onPress={() => setRegister(value => !value)}>
            <Text style={s.register}>{register ? '3andek compte? Dkhol' : 'Ma 3andekch compte? A3mel compte'}</Text>
          </Pressable>}
          <Text style={s.connection}>
            {connection === 'demo'
              ? 'Configurez Supabase pour créer un compte ou vous connecter en toute sécurité.'
              : 'Vos réservations restent liées à votre compte après déconnexion.'}
          </Text>
        </View>
        <Text style={s.bottom}>BLASTI · {connection === 'live' ? 'CONNECTED LIVE' : 'COMPTE SÉCURISÉ'}</Text>
      </ScrollView>
    </KeyboardAvoidingView>
  </SafeAreaView>;
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.paper },
  content: { paddingHorizontal: 18, paddingTop: 9, paddingBottom: 20 },
  brand: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16 },
  slogan: { fontSize: 10, fontWeight: '800', color: '#818e9e' },
  cover: { height: 188, borderRadius: 16, overflow: 'hidden', justifyContent: 'center', padding: 17, backgroundColor: colors.navy },
  coverImage: { borderRadius: 16 },
  shade: { ...StyleSheet.absoluteFill, backgroundColor: '#082f63b8' },
  hero: { fontSize: 25, lineHeight: 29, fontWeight: '900', color: '#fff', letterSpacing: -.5, marginTop: 11 },
  heroSub: { fontSize: 10, color: '#edf3f8', marginTop: 5 },
  form: { backgroundColor: '#fff', borderRadius: 15, borderWidth: 1, borderColor: colors.line, padding: 16, marginTop: 14 },
  formTitle: { fontSize: 18, fontWeight: '900', color: colors.navy },
  formSub: { fontSize: 10, color: colors.muted, marginTop: 5 },
  roles: { flexDirection: 'row', gap: 9, marginTop: 12, marginBottom: 10 },
  roleCard: { flex: 1, height: 47, borderWidth: 1, borderColor: '#e5eaf0', borderRadius: 9, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7 },
  roleActive: { backgroundColor: '#fff5d5', borderColor: '#f3d26b' },
  roleText: { fontSize: 10, fontWeight: '700', color: '#8592a0' },
  roleTextActive: { color: colors.navy },
  input: { height: 42, borderWidth: 1, borderColor: '#e0e6ec', borderRadius: 8, marginTop: 8, paddingHorizontal: 11, fontSize: 11, color: colors.ink },
  submit: { height: 44, backgroundColor: colors.navy, borderRadius: 9, alignItems: 'center', justifyContent: 'center', marginTop: 11 },
  submitText: { fontSize: 11, color: '#fff', fontWeight: '800' },
  register: { fontSize: 9, color: colors.navyLight, textAlign: 'center', fontWeight: '700', marginTop: 11 },
  connection: { fontSize: 9, color: colors.muted, textAlign: 'center', marginTop: 12, lineHeight: 14 },
  bottom: { textAlign: 'center', fontSize: 8, fontWeight: '800', letterSpacing: 1, color: '#98a3af', marginTop: 17 },
});
