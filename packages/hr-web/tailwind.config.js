export default {
  content: ['./index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // Primary brand — matches Flutter _brandGreen / _greenMid
        brand: {
          50:  '#ECFDF5',
          100: '#D1FAE5',
          200: '#A7F3D0',
          300: '#6EE7B7',
          400: '#34D399',
          500: '#10B981',
          600: '#059669',
          700: '#047857',
          800: '#065F46',   // primary — matches Flutter _brandGreen
          900: '#064E3B',
          950: '#022C22',
        },
        // Navy accent — matches Flutter _navyBlue
        navy: {
          50:  '#EEF2FA',
          100: '#D5E0F3',
          200: '#AABFE7',
          300: '#7A9BD7',
          400: '#4F78C7',
          500: '#2B5BB8',
          600: '#1B3A6B',
          700: '#162F57',
          800: '#102344',
          900: '#0A1830',
        },
        accent: {
          400: '#6B6B6B',
          500: '#4A4A4A',
          600: '#333333',
        },
        // Surface / background
        surface: '#F1F8F4',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      boxShadow: {
        card:     '0 1px 3px 0 rgba(6,95,70,0.07), 0 1px 2px -1px rgba(6,95,70,0.07)',
        'card-md':'0 4px 6px -1px rgba(6,95,70,0.07), 0 2px 4px -2px rgba(6,95,70,0.07)',
        'card-lg':'0 10px 15px -3px rgba(6,95,70,0.10), 0 4px 6px -4px rgba(6,95,70,0.10)',
      },
      borderRadius: {
        xl:  '0.75rem',
        '2xl': '1rem',
        '3xl': '1.5rem',
      },
    },
  },
  plugins: [],
};
