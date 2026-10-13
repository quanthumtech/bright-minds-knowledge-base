import type { CSSProperties } from 'react';

type NaoLogoAnimatedProps = {
	className?: string;
	style?: CSSProperties;
	width?: number | string;
	height?: number | string;
	durationSeconds?: number;
	loop?: boolean;
	title?: string;
	color?: string;
};

export default function NaoLogoAnimated({
	className,
	style,
	width,
	height,
	durationSeconds = 2.2,
	loop = true,
	title = 'Bright Minds',
}: NaoLogoAnimatedProps) {
	const animation = loop ? `bm-pulse ${durationSeconds}s ease-in-out infinite` : undefined;

	return (
		<img
			src='/bright-minds-mark.png'
			alt={title}
			aria-hidden={title === '' ? true : undefined}
			className={className}
			style={{ width, height, objectFit: 'contain', animation, ...style }}
		/>
	);
}
