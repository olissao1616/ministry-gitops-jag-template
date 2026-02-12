import { createTheme } from "@mui/material/styles";
import '@bcgov/bc-sans/css/BC_Sans.css';

// rem  16px base equivalent
// 1.375    20px
// 1        16px

// Custom colors
const colors = {
    primary: {
        light: '#BFC9D3',  // #EFEFEF33
        main: '#38598A',   // #BFC9D3
        dark: '#003366',
        contrastText: '#ffffff',

    },
    secondary: {
        light: '#EFEFEF',  // #F5F5F5 '#FDDC8B'
        main: '#FCBA19',   // #FDDC8B
        dark: '#606060',
        contrastText: '#313132',  // '#000' ideal for contrast
    },
    grey: {
        50: '#fafafa',
        100: '#f5f5f5',
        200: '#eeeeee',
        300: '#e0e0e0',
        400: '#bdbdbd',
        500: '#9e9e9e',
        600: '#757575',
        700: '#616161',
        800: '#424242',
        900: '#212121',
    },
    error: '#ff1744',
    warning: '#ff9800',
    info: '#fff',
    success: '#4caf50',
    background: {
        default: '#fff',
        paper: '#fff',
    },
    text: {
        primary: '#313132',
        secondary: '#555555',
        disabled: '#606060'
    },
};

const typography = {
    fontFamily: 'BC Sans, Noto Sans, Arial, sans serif',
    // Base font size
    fontSize: 16, // The base font size for the application.
    // Header styles
    h1: {
        fontSize: '2.125rem', // 34px for large headers
    },
    h2: {
        fontSize: '1.5rem', // 24px for secondary headers
    },
    h3: {
        fontSize: '1.25rem', // 20px for tertiary headers
    },
    h4: {
        fontSize: '1.125rem', // 18px for quaternary headers
    },
    h5: {
        fontSize: '1rem', // 16px, the base font size for smaller headers
    },
    h6: {
        fontSize: '0.875rem', // 14px for the smallest headers
    },
    // You can also customize body1, body2, etc., according to your needs
};

const spacing = (factor:any) => `${5 * factor}px`;

// Define custom breakpoints if needed
// const breakpoints = {
//     values: {
//         xs: 0,
//         sm: 600,
//         md: 960,
//         lg: 1280,
//         xl: 1920,
//     },
// };

// Overrides for Material-UI components
const components = {

    MuiCssBaseline: {
        styleOverrides: {
            body: {
                color: colors.secondary.contrastText,
                fontSize: typography.fontSize,
            }
        }
    },

    MuiButtonBase: {
        styleOverrides: {
            root: {
                '&.MuiTab-root': {
                    textTransform: 'none',
                },
            },
		},
    },

    MuiButton: {
        styleOverrides: {
            root: {
                borderRadius: 4,
                whiteSpace: 'nowrap',
                fontStyle: 'bold',
                textTransform: 'none' as const,
                borderWidth: 2,
                height: spacing(8),
                minWidth: 'fit-content',
                '&:hover': {
                    borderWidth: 2,
                },
            },
            contained: {
                borderColor: `${colors.primary.light}`,
            },

            outlined: {
                color: `${colors.primary.dark}`,
            },
		},
		defaultProps: {
			disableElevation: true, // Remove shadow on buttons by default
		}
    },

    MuiTypography: {
        styleOverrides: {
            root: {
                '&.MuiBreadcrumbs-ol, &.MuiLink-root, &.MuiBreadcrumbs-li, &.MuiFormControlLabel-label': {
                    fontSize: `${typography.h6.fontSize}`,
                },
                '&.MuiFormControlLabel-label': {
                    fontSize: `${typography.h5.fontSize}`,
                },
            }
        }
    },

    MuiAvatar: {
        styleOverrides: {
            root: {
                height: spacing(11),
                width: spacing(11),
            },
        }
    },

    MuiTabs: {
        styleOverrides: {
            root: {
                minHeight: 30,
                paddingTop: 0,
            }
        }
    },

    MuiTab: {
        styleOverrides: {
            root: {
                height: 30,
                minHeight: 30,
                fontWeight: 'bold',
            }
        },
    },

    MuiTabPanel: {
        styleOverrides: {
            root: {
                padding: 0,
                paddingTop: 15,
            }
        }
    },

    MuiFormControl: {
        styleOverrides: {
            root: {
                '&.MuiTextField-root': {
                    marginTop: 0,
                    marginRight: spacing(8),
                    marginLeft: 0,
                },
                '&.JAMLabelledSelect-label':{
                    position: 'relative',
                },
                '&.JAMTextInput-control':{
                    marginTop: 0,
                },
                '&.JAMTextInput-label':{
                    left: 0,
                },
            }
        }
    },

    MuiTableRow: {
        styleOverrides: {
            root: {
                '&.Mui-selected, &.Mui-selected:hover, &.Mui-selected td:after': {
                    backgroundColor: '#FDDC8B !important',
                },
            }
        },
    },

    MuiTableCell: {
        styleOverrides: {
            root: {
                color: 'inherit',
                fontSize: typography.h6.fontSize,
                padding: 2,
                '& .Mui-active .MuiTableSortLabel-icon': {
                    color: `${colors.primary.contrastText}!important`,
                },
            },
            head: {
                backgroundColor: `${colors.primary.main}!important`,
                color: colors.primary.contrastText,
                '& .MuiIconButton-root': {
                    color: colors.primary.contrastText,
                }
            }
        },
    },


    MuiTablePagination: {
        styleOverrides: {
            root: {
                '&.MuiInputLabel-root':{
                    top: 0,
                },
            }
        },
    },
    MuiInputBase: {
        styleOverrides: {
            root: {
                fontSize: 'inherit',
                backgroundColor: colors.background.default,
                padding: spacing(1),
                borderRadius: 1,
                height: spacing(8),
                '&.Mui-disabled': {
                    '&.MuiOutlinedInput-notchedOutline': {
                        height: spacing(8),
                    },
                },
            },
            input: {
                padding: 0,
                '&.MuiInput-input': {
                    fontSize: 'inherit',
                }
            }
        },
    },

    MuiFormLabel: {
        styleOverrides: {
            root: {
                fontSize: typography.h5.fontSize,
                '&.MuiInputLabel-root':{
                    display: 'inline',
                    position: 'relative',
                },
                '&.MuiInputLabel-root.JAMLabelledSelect-label':{
                    display: 'inline',
                    position: 'relative',
                    top: 0,
                    left: 0,
                },
                '&.MuiInputLabel-root.JAMTextInput-label':{
                    display: 'inline',
                    position: 'relative',
                    left: 0,
                    top: 0,
                }
            }
        },
    },

    MuiInputLabel: {
        styleOverrides: {
            root: {
                // Default styles applied when not shrunk
                display: 'inline',
                // variants: 'h5',
                transition: 'none',
                '&.MuiInputLabel-outlined': {
                    left: -14,
                    top: -16,
                },
                // Explicitly targeting the shrunk state
                '&.MuiInputLabel-shrink': {
                    fontSize: typography.h6.fontSize,
                    top: 3,
                    left: 14,
                },
            },
            shrink: {
                transform: 'none !important',
            }
        },
    },

    MuiOutlinedInput:  {
        styleOverrides: {
            root: {
                borderWidth: 2,
                '&.Mui-disabled': {
                    '&:hover .MuiOutlinedInput-notchedOutline': {
                        borderColor: colors.grey[400],
                        borderWidth: 1,
                    },
                },
                // this overrides too much and the others can't change
                '&:hover .MuiOutlinedInput-notchedOutline': {
                    borderWidth: 2,
                    borderColor: colors.secondary.main,
                },
                '&.Mui-focused .MuiOutlinedInput-notchedOutline': {
                    borderColor: colors.primary.main,
                },
                '&.Mui-readOnly .MuiOutlinedInput-notchedOutline': {
                    borderColor: colors.grey[400],
                    borderWidth: 1,
                },
            },
            input: {
                padding: '0 0 0 0.25rem'
            },
        }
    },
    MuiSelect: {
        styleOverrides: {
            select: {
                padding: spacing(1),
                fontSize: typography.h5.fontSize,
            }
        },
    },
    MuiBreadcrumbs: {
        styleOverrides: {
            ol: {
                fontSize: typography.h6.fontSize,
            }
        },
    },
    // Overrides for other components
};

const theme = createTheme({
    palette: {
        primary: {
            light: colors.primary.light,
            main: colors.primary.main,
            dark: colors.primary.dark,
            contrastText: colors.primary.contrastText,
        },
        secondary: {
            light: colors.secondary.light,
            main: colors.secondary.main,
            dark: colors.secondary.dark,
            contrastText: colors.secondary.contrastText,
        },
        error: { main: colors.error },
        warning: { main: colors.warning },
        info: { main: colors.info },
        success: { main: colors.success },
        background: {
            default: colors.background.default,
            paper: colors.background.paper,
        },
        text: {
            primary: colors.text.primary,
            secondary: colors.text.secondary,
            disabled: colors.text.disabled,
        },
    },
    spacing: spacing,
    typography,
    components: components,
    // breakpoints,
    // Other global theme overrides or additions
});

export default theme;