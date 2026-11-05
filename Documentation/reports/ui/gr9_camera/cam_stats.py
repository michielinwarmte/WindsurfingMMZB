import sys, math, numpy as np
for path in sys.argv[1:]:
    d = np.genfromtxt(path, delimiter=',', names=True)
    ax = np.degrees(np.arctan2(d['px'], -d['pz'])); ay = np.degrees(np.arctan2(d['py'], -d['pz']))
    f = np.stack([d['fx'], d['fy'], d['fz']], 1)
    yaw = np.degrees(np.unwrap(np.arctan2(f[:,0], -f[:,2]))); pitch = np.degrees(np.arcsin(np.clip(f[:,1], -1, 1)))
    def d2(a): x = a[2:] - 2*a[1:-1] + a[:-2]; return np.sqrt(np.mean(x**2)), np.max(np.abs(x))
    print(path.split('/')[-1], 'frames', len(d), 'fps %.0f' % (1/np.mean(d['dt'])), 'frac min/max %.2f/%.2f' % (d['frac'].min(), d['frac'].max()))
    print('  board in view, 2nd diff deg (rms, max): horiz %.4f %.4f | vert %.4f %.4f' % (*d2(ax), *d2(ay)))
    print('  camera turn, 2nd diff deg (rms, max): yaw %.4f %.4f | pitch %.4f %.4f' % (*d2(yaw), *d2(pitch)))
    print('  board in view range deg: horiz %.2f..%.2f vert %.2f..%.2f, distance %.2f..%.2f m' % (ax.min(), ax.max(), ay.min(), ay.max(), -d['pz'].max(), -d['pz'].min()))
