import { Alert, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { ChevronRight, CircleHelp, Globe2, LogOut, ShieldCheck } from 'lucide-react-native';
import { colors } from '../src/theme';
import { Card, Eyebrow, Logo } from '../src/ui';
import { useStore } from '../src/store';
import AccessScreen from '../src/access';

export default function ProfileScreen() {
  const { user, signOut, connection } = useStore();
  if (!user) return <AccessScreen/>;
  return <SafeAreaView style={s.safe} edges={['top']}>
    <ScrollView contentContainerStyle={s.content}>
      <View style={s.top}><Logo/><Text style={s.topTitle}>Compte mte3i</Text></View>
      <Card style={s.profileCard}>
        <View style={s.avatar}><Text style={s.avatarText}>{user.name[0]}</Text></View>
        <View style={{ flex: 1 }}><Text style={s.name}>{user.name}</Text><Text style={s.role}>{user.role === 'operator' ? 'Chauffeur · Bab Bhar' : 'Mousfer BLASTI'}</Text></View>
        <ShieldCheck color={connection === 'live' ? colors.green : '#ad8000'} size={19}/>
      </Card>
      <Eyebrow>LES REGLAGES</Eyebrow>
      <Card style={s.menuCard}>
        <MenuRow icon={<Globe2 size={17} color={colors.navy}/>} label="El logha" detail="Derja tounsia" onPress={() => Alert.alert('El logha', 'BLASTI tahki m3ak tounsi.')}/>
        <MenuRow icon={<CircleHelp size={17} color={colors.navy}/>} label="3awenni" detail="Ken 3andek mochkel, a7ki m3ana" onPress={() => Alert.alert('BLASTI', 'Ab3ath mail l bonjour@blasti.tn')}/>
      </Card>
      <Pressable style={s.logout} onPress={() => void signOut().catch(error => Alert.alert('Ma najamnach no5rjou', error instanceof Error ? error.message : '3awed jarreb ba3d chwaya.'))}>
        <LogOut size={17} color="#b25a54"/><Text style={s.logoutText}>O5rej mel compte</Text>
      </Pressable>
      <View style={s.bottom}><Text style={s.brand}>BLASTI · SOUSSA</Text><Text style={s.slogan}>Bla z7am, bla 7ira.</Text></View>
    </ScrollView>
  </SafeAreaView>;
}

function MenuRow({ icon, label, detail, onPress }: { icon: React.ReactNode; label: string; detail: string; onPress: () => void }) {
  return <Pressable style={s.menuRow} onPress={onPress}>
    <View style={s.menuIcon}>{icon}</View><View style={{ flex: 1 }}><Text style={s.menuLabel}>{label}</Text><Text style={s.menuDetail}>{detail}</Text></View>
    <ChevronRight size={17} color="#a1acb7"/>
  </Pressable>;
}

const s = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.paper },
  content: { padding: 17, paddingBottom: 35 },
  top: { height: 44, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 },
  topTitle: { fontSize: 14, fontWeight: '800', color: colors.navy },
  profileCard: { flexDirection: 'row', alignItems: 'center', gap: 11, padding: 14, marginBottom: 20 },
  avatar: { width: 42, height: 42, borderRadius: 21, backgroundColor: '#ffdf91', alignItems: 'center', justifyContent: 'center' },
  avatarText: { fontSize: 16, fontWeight: '900', color: '#624a0c' },
  name: { fontSize: 12, fontWeight: '800', color: colors.navy },
  role: { fontSize: 9, color: colors.muted, marginTop: 4 },
  menuCard: { paddingHorizontal: 12, paddingVertical: 3, marginTop: 8 },
  menuRow: { minHeight: 63, flexDirection: 'row', alignItems: 'center', gap: 9, borderBottomWidth: 1, borderColor: '#f0f2f4' },
  menuIcon: { width: 30, height: 30, borderRadius: 9, backgroundColor: '#eef3f8', alignItems: 'center', justifyContent: 'center' },
  menuLabel: { fontSize: 10, fontWeight: '800', color: '#30465f' },
  menuDetail: { fontSize: 8, color: '#8a97a4', marginTop: 4 },
  logout: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, marginTop: 18, padding: 12 },
  logoutText: { fontSize: 10, color: '#b25a54', fontWeight: '800' },
  bottom: { alignItems: 'center', marginTop: 27 },
  brand: { fontSize: 9, letterSpacing: 1.2, fontWeight: '900', color: '#8391a0' },
  slogan: { fontSize: 12, color: '#a6afb8', marginTop: 6 },
});
